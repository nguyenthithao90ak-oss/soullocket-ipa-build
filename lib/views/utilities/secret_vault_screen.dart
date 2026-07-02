import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/services/purchase_service.dart';
import '../../utils/services/pending_upload_service.dart';
import '../../utils/services/storage_service.dart';
import '../../utils/app_error_mapper.dart';
import 'dart:ui' as ui;
import '../../utils/services/activity_history_service.dart';
import '../../utils/services/auth_service.dart';
import '../../utils/services/connectivity_service.dart';
import '../../utils/services/encryption_service.dart';
import '../../utils/services/secret_vault_reset_service.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../core/sl_theme.dart';
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
  String _encStatusMsg = L10nService().translate('util_angchmkhak_2777b3');
  bool _hasMorePhotos = false;
  bool _isLoadingMorePhotos = false;
  int? _oldestLoadedPhotoTs;
  bool _didPromptPendingVaultUploadRetry = false;

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _listenResetRequest();
    _networkSub = ConnectivityService().isOnlineStream.listen((isOnline) {
      if (!isOnline && mounted) {
        _safeSetState(() {
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
          content: Text(context.tr('util_lnuploadkh_6efff4')),
          action: SnackBarAction(
            label: context.tr('util_thli_4dffdf'),
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
          SnackBar(
            content: Text(context.tr('util_khngcnnhct_6c1d76')),
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
      _safeSetState(() => _isPreparingVault = true);
    } else {
      _isPreparingVault = true;
    }
    if (!ConnectivityService().isOnline) {
      if (mounted) {
        _safeSetState(() {
          _encryptionReady = false;
          _encStatusMsg =
              'Không có kết nối mạng.\nKho ảnh mật yêu cầu Internet để xác thực.';
        });
      }
      if (mounted) {
        _safeSetState(() => _isPreparingVault = false);
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
        _safeSetState(() {
          _encryptionReady = true;
          _encStatusMsg = context.tr('util_khomtangm_5f209b');
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
          _safeSetState(() {
            _encryptionReady = false;
            _isPreparingVault = false;
            _encStatusMsg = context.tr('util_hymkhomt_ddffe1');
          });
        }
        return;
      }

      if (passphrase == _recoveryAction) {
        final recoveryCode = await _showRecoveryCodeInputDialog();
        if (!mounted || recoveryCode == null) return;
        _safeSetState(() {
          _encryptionReady = false;
          _encStatusMsg = context.tr('util_angxcthcmk_ba443e');
        });
        await _enc
            .unlockHouseKeyWithRecoveryCode(widget.houseId, recoveryCode)
            .timeout(_vaultPrepareTimeout);
        if (!mounted) return;
        _safeSetState(() {
          _encryptionReady = true;
          _encStatusMsg = context.tr('util_khomtmbngm_cd1d8d');
          _hasRecoveryCode = true;
        });
        _loadPhotos();
        unawaited(_promptPendingVaultUploadRetryIfNeeded());
        return;
      }

      _safeSetState(() {
        _encryptionReady = false;
        _encStatusMsg = context.tr('util_angxlkha_922e10');
      });

      await _enc
          .unlockHouseKey(widget.houseId, passphrase)
          .timeout(_vaultPrepareTimeout);
      if (mounted) {
        final recoveryCode = await _enc
            .createRecoveryCodeIfMissing(widget.houseId)
            .timeout(_vaultPrepareTimeout);
        if (!mounted) return;
        _safeSetState(() {
          _encryptionReady = true;
          _encStatusMsg = hasSetup
              ? context.tr('util_khomtmthnh_0e31d1')
              : context.tr('util_thitlpkhom_cf352c');
          _hasRecoveryCode = true;
        });
        if (recoveryCode != null && mounted) {
          await _showGeneratedRecoveryCodeDialog(
            recoveryCode,
            title: context.tr('util_mkhiphcmi_44cc09'),
            message:
                context.tr('util_lumnyniant_6e9a93'),
          );
        }
      }
      _loadPhotos();
      unawaited(_promptPendingVaultUploadRetryIfNeeded());
    } on TimeoutException {
      if (mounted) {
        _safeSetState(() {
          _encryptionReady = false;
          _encStatusMsg = context.tr('util_thaotcmkho_721330');
        });
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() {
          _encryptionReady = false;
          _encStatusMsg = AppErrorMapper.resolve(e).message;
        });
      }
    } finally {
      if (mounted) {
        _safeSetState(() => _isPreparingVault = false);
      } else {
        _isPreparingVault = false;
      }
    }
  }

  Future<void> _loadPhotos() async {
    final legacyPasswordRequiredText =
        context.tr('util_cnnhpmtkhu_b5f391');
    final legacyMigrationText = context.tr('util_cnidungccn_44f5ff');
    final loadFailedText = context.tr('util_khngthtikh_150eff');
    final query = _dbRef
        .child('houses/${widget.houseId}/private_secure')
        .orderByChild('ts')
        .limitToLast(_initialVisiblePhotoLimit);
    try {
      final event = await query.get();
      final raw = event.value;
      if (raw is Map) {
        final data = Map<dynamic, dynamic>.from(raw);
        bool needsLegacyMigrationLocal = false;
        final loaded = await Future.wait(
          data.entries.map((entry) async {
            final value = entry.value;
            if (value is! Map) {
              return <String, dynamic>{'id': entry.key};
            }
            final item = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(value));
            item['id'] = entry.key;

            if (item['caption'] != null &&
                item['caption'].toString().isNotEmpty) {
              try {
                final decrypted = await _enc.decryptMessage(
                  widget.houseId,
                  item['caption'].toString(),
                );
                item['caption_plain'] = decrypted;
                if (decrypted == legacyPasswordRequiredText) {
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
          _safeSetState(() => _encStatusMsg = legacyMigrationText);
        }

        loaded.sort((a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0));
        if (mounted) {
          final oldestTs =
              loaded.isEmpty ? null : (loaded.last['ts'] as num?)?.toInt();
          _safeSetState(() {
            _photos = loaded;
            _oldestLoadedPhotoTs = oldestTs;
            _hasMorePhotos = loaded.length >= _initialVisiblePhotoLimit;
            _isLoadingMorePhotos = false;
          });
        }
      } else {
        if (mounted) {
          _safeSetState(() {
            _photos = [];
            _oldestLoadedPhotoTs = null;
            _hasMorePhotos = false;
            _isLoadingMorePhotos = false;
          });
        }
      }
    } catch (error) {
      debugPrint(
        'Secret vault load failed: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: loadFailedText,
        ).message}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi tải ảnh: $error'),
          backgroundColor: SLColors.danger,
        ));
        _safeSetState(() => _isLoadingMorePhotos = false);
      }
    }
  }

  void _loadMorePhotos() async {
    if (_isLoadingMorePhotos || !_hasMorePhotos) {
      return;
    }
    final legacyPasswordRequiredText =
        context.tr('util_cnnhpmtkhu_b5f391');
    _safeSetState(() {
      _isLoadingMorePhotos = true;
    });
    final oldestTs = _oldestLoadedPhotoTs;
    if (oldestTs == null) {
      if (mounted) {
        _safeSetState(() => _isLoadingMorePhotos = false);
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
          _safeSetState(() {
            _hasMorePhotos = false;
            _isLoadingMorePhotos = false;
          });
        }
        return;
      }

      final raw = snapshot.value;
      if (raw is! Map) {
        if (mounted) {
          _safeSetState(() {
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
              if (decrypted == legacyPasswordRequiredText) {
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
            context.tr('util_cnidungccn_44f5ff');
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
      _safeSetState(() {
        _photos = nextPhotos;
        _oldestLoadedPhotoTs = nextOldestTs;
        _hasMorePhotos =
            loadedMore.length >= StorageService.secretVaultPageSize;
        _isLoadingMorePhotos = false;
      });
    } catch (_) {
      if (mounted) {
        _safeSetState(() => _isLoadingMorePhotos = false);
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
        SnackBar(content: Text(context.tr('util_vuilngmkha_19eeeb'))),
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

    // Total cap check
    final vaultCountSnap = await _dbRef
        .child('houses/${widget.houseId}/vaultCount')
        .get();
    final currentTotal = vaultCountSnap.value is num
        ? (vaultCountSnap.value as num).toInt()
        : 0;
    if (currentTotal >= StorageService.secretVaultTotalCap) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Kho mật đã đạt tối đa 365 ảnh. Hãy xóa bớt để thêm ảnh mới.',
          ),
          backgroundColor: SLColors.warning,
        ));
      }
      return;
    }

    if (enforceLocalDailyLimit && uploadedToday >= dailyLimit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Đã đạt giới hạn $dailyLimit ảnh/ngày.',
          ),
          backgroundColor: SLColors.danger,
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
        backgroundColor: SLColors.warning,
      ));
    }

    if (enforceLocalDailyLimit && uploadedToday + images.length > dailyLimit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Chỉ còn lại ${dailyLimit - uploadedToday} lượt đăng hôm nay. Bạn đã chọn ${images.length} ảnh.'),
          backgroundColor: SLColors.warning,
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
        builder: (ctx) => Theme(
          data: Theme.of(ctx).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              hintStyle: const TextStyle(color: Colors.white38),
              labelStyle: const TextStyle(color: Colors.white70),
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
                borderSide: const BorderSide(color: SLColors.danger),
              ),
            ),
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocalState) => AlertDialog(
              backgroundColor: SLColors.darkBgCard,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            title: Text(context.tr('util_thmghichty_5651be'),
                style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800, color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: captionCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 1000,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white12,
                    hintText: context.tr('util_mtkhonhkhc_52663c'),
                    hintStyle: const TextStyle(color: Colors.white38),
                    counterText: '',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SLColors.danger)),
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
                        activeColor: SLColors.danger,
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
                          context.tr('util_khnghilitr_e3bf9f'),
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
                  child: Text(context.tr('util_bqua_874b71'),
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
                  child: Text(context.tr('util_thm_56ef2c'),
                      style: SLTheme.quicksand(color: SLColors.danger))),
            ],
          ),
        ),
      ),
    );
      if (result == null) return;
      captionPlain = result;
    }

    _safeSetState(() => _isLoading = true);

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
        if (!mounted) {
          // Lưu pending cho lần sau
          await _savePendingVaultUpload(
            imagePaths: images.map((e) => e.path).toList(),
            encryptedCaption: encryptedCaption,
          );
          return;
        }
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
          backgroundColor: SLColors.success,
        ));
      }
    } catch (e, stack) {
      debugPrint('Vault upload error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Lỗi tải lên: $e'),
            backgroundColor: SLColors.danger,
        ));
      }
    } finally {
      if (mounted) {
        _safeSetState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final id = photo['id']?.toString() ?? '';
    if (id.isEmpty) {
      return;
    }

    final restorePayload = Map<String, dynamic>.from(photo)
      ..remove('id')
      ..remove('url');

    await ActivityHistoryService.instance.add(
      context.tr('util_xamtnhring_66ec90'),
      houseId: widget.houseId,
      title: context.tr('util_xanhringt_8778f3'),
      subtitle: '',
      action: 'delete',
      module: 'secret_vault',
      entityType: 'secret_photo',
      entityId: id,
      sourceLabel: context.tr('util_khobmt_e05057'),
      previewUrl: '',
      previewType: 'private',
      restorePath: 'houses/${widget.houseId}/private_secure/$id',
      restorePayload: restorePayload,
    );

    final url = photo['url']?.toString() ?? '';
    final storagePath = photo['storagePath']?.toString() ?? '';

    if (url.isNotEmpty) {
      // deleteImageByUrl đã hỗ trợ R2
      await _storageService.deleteImageByUrl(url);
    } else if (storagePath.isNotEmpty) {
      await _storageService.deleteFileByPath(storagePath);
    }

    await _dbRef.child('houses/${widget.houseId}/private_secure/$id').remove();
    await _dbRef.child('houses/${widget.houseId}/vaultCount')
        .set(ServerValue.increment(-1));
  }

  Future<String?> _showPassphraseDialog({required bool hasSetup}) async {
    final passphraseCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscurePass = true;
    var obscureConfirm = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: Theme.of(ctx).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            hintStyle: const TextStyle(color: Colors.white38),
            labelStyle: const TextStyle(color: Colors.white70),
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
              borderSide: const BorderSide(color: SLColors.danger),
            ),
          ),
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            backgroundColor: SLColors.darkBgCard,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            hasSetup ? context.tr('util_mkhakhomt_421171') : context.tr('util_thitlpkhom_792656'),
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
                      ? context.tr('util_nhpmtkhukh_e4639a')
                      : context.tr('util_tomtkhukho_e3de4f'),
                  style: SLTheme.quicksand(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passphraseCtrl,
                  obscureText: obscurePass,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 32,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white12,
                    hintText: context.tr('util_mtkhutithi_d4f304'),
                    hintStyle: const TextStyle(color: Colors.white38),
                    counterText: '',
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
                      borderSide: const BorderSide(color: SLColors.danger),
                    ),
                  ),
                ),
                if (!hasSetup) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscureConfirm,
                    style: const TextStyle(color: Colors.white),
                    maxLength: 32,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white12,
                      hintText: context.tr('util_nhplimtkhu_eee7a7'),
                      hintStyle: const TextStyle(color: Colors.white38),
                      counterText: '',
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
                        borderSide: const BorderSide(color: SLColors.danger),
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
                  context.tr('util_dngmkhiphc_698038'),
                  style: SLTheme.quicksand(color: SLColors.info),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.tr('util_ng_aecc61'),
                style: SLTheme.quicksand(color: Colors.white38),
              ),
            ),
            TextButton(
              onPressed: () {
                final passphrase = passphraseCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();
                if (passphrase.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('util_mtkhukhomt_e98699')),
                    ),
                  );
                  return;
                }
                if (!hasSetup && passphrase != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('util_mtkhunhpli_f31f82')),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, passphrase);
              },
              child: Text(
                hasSetup ? context.tr('util_mkha_e16936') : context.tr('util_thitlp_486746'),
                style: SLTheme.quicksand(color: SLColors.danger),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Future<String?> _showRecoveryCodeInputDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: Theme.of(ctx).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            hintStyle: const TextStyle(color: Colors.white38),
            labelStyle: const TextStyle(color: Colors.white70),
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
              borderSide: const BorderSide(color: SLColors.danger),
            ),
          ),
        ),
        child: AlertDialog(
          backgroundColor: SLColors.darkBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('util_nhpmkhiphc_44a271'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white),
          maxLength: 30,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white12,
            hintText: 'VD: ABCD-EFGH-JKLM-NPQR',
            hintStyle: const TextStyle(color: Colors.white38),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('util_ng_f63d1e'),
              style: SLTheme.quicksand(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              context.tr('util_mkho_68a790'),
              style: SLTheme.quicksand(color: SLColors.danger),
            ),
          ),
        ],
      ),
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
        backgroundColor: SLColors.darkBgCard,
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
                  color: SLColors.success,
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
                SnackBar(content: Text(context.tr('util_saochpmkhi_b1f0e5'))),
              );
            },
            child: Text(
              context.tr('util_saochp_cbfba9'),
              style: SLTheme.quicksand(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('util_tilu_7a1601'),
              style: SLTheme.quicksand(color: SLColors.danger),
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
      _safeSetState(() => _hasRecoveryCode = true);
      await _showGeneratedRecoveryCodeDialog(
        recoveryCode,
        title: context.tr('util_mkhiphci_dcdad7'),
        message: context.tr('util_mcshthiulc_6de8b6'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.resolve(
              e,
              fallbackMessage:
                  context.tr('util_chathtolim_b5c569'),
            ).message,
          ),
        ),
      );
    }
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SLColors.darkBgCard,
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
                color: _hasPendingReset ? SLColors.warning : SLColors.danger,
              ),
              title: Text(
                _hasPendingReset
                    ? context.tr('util_thuhiyucur_db8240')
                    : context.tr('util_resetkhonh_c48d2d'),
                style: SLTheme.quicksand(color: Colors.white),
              ),
              subtitle: Text(
                _hasPendingReset
                    ? 'Kho sẽ bị xoá lúc ${_formatResetSchedule(_pendingResetRequest?.scheduledAt ?? 0)} nếu không thu hồi.'
                    : context.tr('util_xcnhnquaem_043f1a'),
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
              title: Text(context.tr('util_imtkhu_ff6fe7'),
                  style: SLTheme.quicksand(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showChangePasswordDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.key_rounded, color: SLColors.infoLight),
              title: Text(
                _hasRecoveryCode ? context.tr('util_tolimkhiph_6a2c38') : context.tr('util_tomkhiphc_67ed4c'),
                style: SLTheme.quicksand(color: Colors.white),
              ),
              subtitle: Text(
                _hasRecoveryCode
                    ? context.tr('util_mymicthdng_fa5403')
                    : context.tr('util_nntotrnhmt_9b80a1'),
                style: SLTheme.quicksand(color: Colors.white54),
              ),
              onTap: _handleRegenerateRecoveryCode,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: SLColors.warning),
              title: Text(context.tr('util_khalikhomt_c053ec'),
                  style: SLTheme.quicksand(color: SLColors.warning)),
              onTap: () {
                Navigator.pop(ctx);
                _enc.clearCache(widget.houseId);
                _safeSetState(() {
                  _encryptionReady = false;
                  _encStatusMsg = context.tr('util_khakhomt_86fa56');
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
      builder: (ctx) => Theme(
        data: Theme.of(ctx).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            hintStyle: const TextStyle(color: Colors.white38),
            labelStyle: const TextStyle(color: Colors.white70),
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
              borderSide: const BorderSide(color: SLColors.danger),
            ),
          ),
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            backgroundColor: SLColors.darkBgCard,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(context.tr('util_imtkhu_ff6fe7'),
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
                  maxLength: 32,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white12,
                    labelText: context.tr('util_mtkhuc_36b0a2'),
                    labelStyle: const TextStyle(color: Colors.white70),
                    counterText: '',
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
                  maxLength: 32,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white12,
                    labelText: context.tr('util_mtkhumi_ccef95'),
                    labelStyle: const TextStyle(color: Colors.white70),
                    counterText: '',
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
                  maxLength: 32,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white12,
                    labelText: context.tr('util_nhplimtkhu_82a9a4'),
                    labelStyle: const TextStyle(color: Colors.white70),
                    counterText: '',
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
                      child: Text(context.tr('util_tiqunmtkhu_e343b1'),
                          style: SLTheme.quicksand(
                              color: SLColors.info,
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
                  Text(context.tr('util_hy_1e4050'), style: SLTheme.quicksand(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () async {
                final oldPass = oldPassCtrl.text.trim();
                final newPass = newPassCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();

                if (oldPass.isEmpty || newPass.isEmpty) return;
                if (newPass.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(context.tr('util_mtkhumiphi_0da717'))));
                  return;
                }
                if (newPass != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('util_mtkhumicha_83d367'))));
                  return;
                }

                _safeSetState(() {
                  _encryptionReady = false;
                  _encStatusMsg = context.tr('util_angimtkhuv_db04a3');
                });
                Navigator.pop(ctx);

                try {
                  await _enc.changePassphrase(widget.houseId, oldPass, newPass);
                  final recoveryCode =
                      await _enc.createRecoveryCodeIfMissing(widget.houseId);
                  if (mounted) {
                    _safeSetState(() {
                      _encryptionReady = true;
                      _encStatusMsg = context.tr('util_imtkhuthnh_82a076');
                      _hasRecoveryCode = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.tr('util_imtkhuthnh_e54dc2')),
                        backgroundColor: SLColors.success));
                    if (recoveryCode != null) {
                      await _showGeneratedRecoveryCodeDialog(
                        recoveryCode,
                        title: context.tr('util_mkhiphcmi_44cc09'),
                        message:
                            context.tr('util_mtkhuinnmk_e727c7'),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    _safeSetState(() {
                      _encryptionReady = true;
                      _encStatusMsg = context.tr('util_khomtm_a6c43e');
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            context.tr('util_mtkhucchan_decb9b')),
                        backgroundColor: SLColors.danger));
                  }
                }
              },
              child: Text(context.tr('util_imtkhu_82844c'),
                  style: SLTheme.quicksand(color: SLColors.danger)),
            ),
          ],
        ),
      ),
    ),
  );
  }

  void _showVaultResetInfoDialog(bool isWithin12Hours) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SLColors.darkBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _hasPendingReset ? context.tr('util_yucureseta_74986f') : context.tr('util_resetkhonh_c48d2d'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.bold,
            color: _hasPendingReset ? SLColors.warning : SLColors.danger,
          ),
        ),
        content: Text(
          _hasPendingReset
              ? 'Kho ảnh mật đã được lên lịch xóa vào ${_formatResetSchedule(_pendingResetRequest?.scheduledAt ?? 0)}. ${context.tr('util_trongthigi_6645aa')}'
              : '${context.tr('util_resetkhonh_d0b294')}${context.tr('util_bnphixcnhn_b3fe0e')}${isWithin12Hours ? '\n\nDù bạn vừa đổi mật khẩu gần đây, hệ thống vẫn áp dụng thời gian chờ đủ 1 ngày trước khi xoá dữ liệu.' : ''}',
          style: SLTheme.quicksand(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('util_hu_9daba0'),
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
              _hasPendingReset ? context.tr('util_thuhiyucu_cc5144') : context.tr('util_xcnhnquaem_645252'),
              style: SLTheme.quicksand(
                color: _hasPendingReset ? SLColors.warning : SLColors.danger,
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
        backgroundColor: SLColors.darkBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('util_khiphckhom_4fc524'),
            style: SLTheme.quicksand(
                fontWeight: FontWeight.bold, color: SLColors.danger)),
        content: Text(
            isWithin12Hours
                ? context.tr('util_vbnthitlpm_b25608')
                : 'Vì kho này dùng mã hóa đầu cuối, nếu bạn quên mật khẩu thì toàn bộ ảnh bí mật cũ sẽ bị xóa vĩnh viễn và không thể khôi phục.\n\nBạn có chắc chắn muốn xóa kho mật cũ để tạo lại mật khẩu mới không?',
            style: SLTheme.quicksand(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text(context.tr('util_hy_1e4050'), style: SLTheme.quicksand(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _safeSetState(() {
                _encryptionReady = false;
                _encStatusMsg = context.tr('util_angxlkhiph_5f7957');
              });
              try {
                if (isWithin12Hours) {
                  await _enc.resetVaultKeepData(widget.houseId);
                  if (mounted) {
                    _safeSetState(() {
                      _encStatusMsg =
                          context.tr('util_khomtcrese_b11161');
                      _hasRecoveryCode = false;
                      // Không clear _photos, giữ nguyên dữ liệu trên UI
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            context.tr('util_resetmtkhu_02f484')),
                        backgroundColor: SLColors.success));
                  }
                } else {
                  await _enc.resetVault(widget.houseId);
                  if (mounted) {
                    _safeSetState(() {
                      _encStatusMsg = context.tr('util_khomtcrese_aee917');
                      _photos = [];
                      _hasRecoveryCode = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.tr('util_xakhomtchy_906978')),
                        backgroundColor: SLColors.warning));
                  }
                }
                if (mounted) {
                  _prepareVault(); // Mở lại dialog thiết lập
                }
              } catch (e) {
                if (mounted) {
                  _safeSetState(() {
                    _encStatusMsg = context.tr('util_lixlkhomt_6c14b7');
                  });
                }
              }
            },
            child: Text(isWithin12Hours ? context.tr('util_tiptc_555f1f') : context.tr('util_xavtoli_90b1ee'),
                style: SLTheme.quicksand(
                    color: SLColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Hầm bí mật',
            style: SLTheme.quicksand(fontWeight: FontWeight.w900, color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tính năng:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                SizedBox(height: 4),
                Text('- Nơi an toàn nhất để cất giữ hình ảnh và video nhạy cảm, riêng tư.\n- Bảo vệ bằng mã PIN hoặc FaceID/Vân tay.\n- Tùy chọn "Mã PIN giả" để hiển thị một hầm trống khi bị ép buộc mở.', style: TextStyle(color: Colors.white60)),
                SizedBox(height: 12),
                Text('Cách sử dụng:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                SizedBox(height: 4),
                Text('- Thiết lập mã PIN lần đầu khi truy cập.\n- Bấm biểu tượng + để thêm ảnh/video từ thư viện máy.\n- Bật tính năng Mã PIN giả trong phần cài đặt của hầm để tăng cường bảo mật.', style: TextStyle(color: Colors.white60)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đã hiểu', style: TextStyle(color: Colors.blueAccent)),
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
          context.tr('util_khonhbmt_359a5b'),
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
            onPressed: () => _showInfoDialog(context),
          ),
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
            colors: [SLColors.darkBorder, SLColors.darkBgMain],
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
