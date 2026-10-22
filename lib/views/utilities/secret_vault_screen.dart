import 'package:soullocket_app/utils/locale_date_format.dart';
import 'dart:async';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../../utils/services/secret_vault_upload_identity.dart';
import '../../utils/services/secret_vault_media_policy.dart' as vault_policy;
import 'package:flutter/material.dart';
import 'widgets/vault_gallery_layout.dart';
import 'package:soullocket_app/widgets/app_help_center.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/services/purchase_service.dart';
import '../../utils/services/pending_upload_service.dart';
import '../../utils/services/storage/storage_service.dart';
import '../../utils/app_error_mapper.dart';
import 'dart:ui' as ui;
import '../../utils/services/activity_history_service.dart';
import '../../utils/services/auth_service.dart';
import '../../utils/services/connectivity_service.dart';
import '../../utils/services/encryption_service.dart';
import '../../utils/services/secret_vault_reset_service.dart';
import '../../utils/services/vault_media_url_service.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../core/sl_theme.dart';
import '../home/tabs/settings/security/security_otp_dialogs.dart';
import '../ui_prefs.dart';
import '../../widgets/sl_toast.dart';
import '../../widgets/stable_future_builder.dart';
import 'secret_vault/vault_access_surface.dart';

part 'secret_vault/secret_vault_reset_flow.dart';
part 'secret_vault/secret_vault_pending_upload_flow.dart';
part 'secret_vault/secret_vault_display_section.dart';
part 'secret_vault/secret_vault_gallery_section.dart';

// ── Bảng màu riêng cho Kho bí mật (dark violet theme) ──
const Color _vaultBg = Color(0xFF0B1220);
const Color _vaultBgAlt = Color(0xFF111D33);
const Color _vaultField = Color(0xFF172642);
const Color _vaultBorder = Color(0xFF2B4166);
const Color _vaultBorderFocus = Color(0xFF62D9FF);
const Color _vaultTextPrimary = Color(0xFFF3F7FF);
const Color _vaultTextSecondary = Color(0xFFAABBD4);
const Color _vaultTextHint = Color(0xFF7184A2);
const Color _vaultAccent = Color(0xFF62D9FF);
const int _initialVisiblePhotoLimit = StorageService.secretVaultPageSize;
const Duration _vaultPrepareTimeout = Duration(seconds: 15);

/// Chờ Auth khôi phục lần đầu, nhưng không cho màn cũ nhận tài khoản mới.
class SecretVaultSessionScope {
  SecretVaultSessionScope({required this.houseId, String? initialUid})
    : _uid = initialUid?.isNotEmpty == true ? initialUid : null;

  final String houseId;
  String? _uid;
  bool _ended = false;

  String? get uid => _uid;

  bool observeAuthUser(String? uid) {
    if (_ended) return false;
    final nextUid = uid?.isNotEmpty == true ? uid : null;
    if (_uid == null) {
      _uid = nextUid;
      return true;
    }
    if (nextUid == _uid) return true;
    _ended = true;
    return false;
  }

  bool canPrepare({
    required String? currentUid,
    required String currentHouseId,
  }) =>
      !_ended &&
      currentHouseId == houseId &&
      (_uid == null || currentUid == _uid);

  bool isCurrent({
    required String? currentUid,
    required String currentHouseId,
  }) =>
      _uid != null &&
      canPrepare(currentUid: currentUid, currentHouseId: currentHouseId);
}

// Cùng timestamp vẫn giữ thứ tự khóa RTDB để cursor không bỏ sót ảnh.
int _compareVaultPhotos(Map<String, dynamic> a, Map<String, dynamic> b) {
  final byTimestamp = (b['ts'] as num? ?? 0).compareTo(a['ts'] as num? ?? 0);
  return byTimestamp != 0
      ? byTimestamp
      : (b['id']?.toString() ?? '').compareTo(a['id']?.toString() ?? '');
}

/// Thử lại thao tác kho khi token gặp lỗi tạm thời; đổi phiên thì bỏ kết quả.
Future<T> readSecretVaultWithAuthRetry<T>({
  required Future<void> Function(bool forceRefresh) prepareToken,
  required Future<T> Function() read,
  required bool Function() isCurrentSession,
  Duration timeout = _vaultPrepareTimeout,
  void Function(FirebaseException error)? onRetry,
}) async {
  final elapsed = Stopwatch()..start();

  void checkSession() {
    if (!isCurrentSession()) {
      throw FirebaseAuthException(code: 'unauthenticated');
    }
  }

  Future<R> runStage<R>(Future<R> Function() action) async {
    checkSession();
    final remaining = timeout - elapsed.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('Secret vault read timed out', timeout);
    }
    final result = await action().timeout(remaining);
    checkSession();
    return result;
  }

  await runStage(() => prepareToken(false));
  try {
    return await runStage(read);
  } on FirebaseException catch (error) {
    final code = error.code.toLowerCase().replaceAll('_', '-');
    if (error.plugin != 'firebase_database' ||
        !const {
          'permission-denied',
          'unknown',
          'unauthenticated',
          'unavailable',
          'internal',
          'internal-error',
          'network-request-failed',
        }.contains(code)) {
      rethrow;
    }
    checkSession();
    onRetry?.call(error);
    await runStage(() => prepareToken(true));
    return runStage(read);
  }
}

class SecretVaultScreen extends StatefulWidget {
  final String houseId;

  const SecretVaultScreen({super.key, required this.houseId});

  @override
  SecretVaultScreenState createState() => SecretVaultScreenState();
}

class SecretVaultScreenState extends State<SecretVaultScreen> {
  static const String _recoveryAction = '__use_recovery_code__';
  late final SecretVaultSessionScope _vaultSession;
  String get _vaultUid => _vaultSession.uid ?? '';
  late final String _vaultHouseId;
  late final Future<VipAccessInfo> _vaultPlan;
  StreamSubscription<User?>? _vaultAuthSub;
  bool get _vaultScopeCanPrepare =>
      mounted &&
      _vaultSession.canPrepare(
        currentUid: FirebaseAuth.instance.currentUser?.uid,
        currentHouseId: widget.houseId,
      );
  bool get _vaultScopeIsCurrent =>
      mounted &&
      _vaultSession.isCurrent(
        currentUid: FirebaseAuth.instance.currentUser?.uid,
        currentHouseId: widget.houseId,
      );

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final EncryptionService _enc = EncryptionService();
  final SecretVaultResetService _vaultResetService = SecretVaultResetService();
  final VaultMediaUrlService _vaultMediaUrlService =
      VaultMediaUrlService.instance;
  int _vaultMediaGeneration = 0;
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
  String? _oldestLoadedPhotoId;
  bool _didPromptPendingVaultUploadRetry = false;

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _vaultHouseId = widget.houseId;
    _vaultSession = SecretVaultSessionScope(
      houseId: _vaultHouseId,
      initialUid: FirebaseAuth.instance.currentUser?.uid,
    );
    _vaultPlan = PurchaseService().getVipAccessInfo();
    _vaultAuthSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (_vaultSession.observeAuthUser(user?.uid)) {
        if (_vaultScopeIsCurrent) unawaited(_prepareVault());
        return;
      }
      _photosSub?.cancel();
      _resetRequestSub?.cancel();
      _enc.clearCache(_vaultHouseId);
      _clearVaultMediaCache();
      _safeSetState(() {
        _encryptionReady = false;
        _photos = [];
        _pendingResetRequest = null;
        _encStatusMsg = AppErrorMapper.authSyncMessage;
      });
    });
    _networkSub = ConnectivityService().isOnlineStream.listen((isOnline) {
      if (!isOnline && mounted) {
        _safeSetState(() {
          _encryptionReady = false;
          _encStatusMsg = L10nService().translate('vault_no_connection');
          _photos = [];
          _hasMorePhotos = false;
          _isLoadingMorePhotos = false;
          _oldestLoadedPhotoTs = null;
          _oldestLoadedPhotoId = null;
        });
        _enc.clearCache(widget.houseId);
        _clearVaultMediaCache();
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
    _vaultAuthSub?.cancel();
    _networkSub?.cancel();
    _photosSub?.cancel();
    _resetRequestSub?.cancel();
    _clearVaultMediaCache();
    super.dispose();
  }

  void _clearVaultMediaCache() {
    _vaultMediaGeneration++;
    _vaultMediaUrlService.clearCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  Future<T> _readVaultWithAuthRetry<T>(
    String operation,
    Future<T> Function() read,
  ) {
    User? user = FirebaseAuth.instance.currentUser;
    final generation = _vaultMediaGeneration;
    final houseId = widget.houseId;
    return readSecretVaultWithAuthRetry(
      isCurrentSession: () =>
          _vaultScopeCanPrepare &&
          widget.houseId == houseId &&
          _vaultMediaGeneration == generation,
      prepareToken: (forceRefresh) async {
        user ??= await FirebaseAuth.instance
            .idTokenChanges()
            .where((candidate) => candidate != null)
            .cast<User>()
            .first
            .timeout(_vaultPrepareTimeout);
        if (!_vaultScopeCanPrepare ||
            !_vaultSession.observeAuthUser(user!.uid) ||
            !_vaultScopeIsCurrent) {
          throw FirebaseAuthException(code: 'unauthenticated');
        }
        final token = await user!.getIdToken(forceRefresh);
        if (token == null || token.trim().isEmpty) {
          throw FirebaseAuthException(code: 'unauthenticated');
        }
      },
      read: read,
      onRetry: (error) => debugPrint(
        'Secret vault read retry: $operation/${error.plugin}/${error.code}',
      ),
    );
  }

  Future<String> _resolveVaultPhotoUrl(Map<String, dynamic> photo) async {
    final storagePath = photo['storagePath']?.toString().trim() ?? '';
    final mediaId = photo['id']?.toString().trim() ?? '';
    if (storagePath.isNotEmpty && mediaId.isNotEmpty) {
      return _vaultMediaUrlService.resolveUrl(
        storagePath: storagePath,
        houseId: widget.houseId,
        mediaId: mediaId,
      );
    }

    // Chỉ dữ liệu cũ chưa có storagePath mới được phép dùng URL trực tiếp.
    final legacyUrl = photo['url']?.toString().trim() ?? '';
    return VaultMediaUrlService.isPublicUrl(legacyUrl) ? legacyUrl : '';
  }

  Widget _buildVaultImage(
    Map<String, dynamic> photo, {
    required BoxFit fit,
    required Widget loading,
    required Widget error,
    double? width,
    double? height,
    int? cacheWidth,
  }) {
    return StableFutureBuilder<String>(
      requestKey: (
        FirebaseAuth.instance.currentUser?.uid,
        widget.houseId,
        _vaultMediaGeneration,
        photo['id'],
        photo['storagePath'],
        photo['url'],
      ),
      load: () => _resolveVaultPhotoUrl(photo),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return loading;
        }
        final signedUrl = snapshot.data?.trim() ?? '';
        if (signedUrl.isEmpty) {
          return error;
        }
        return Image.network(
          signedUrl,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : loading,
          errorBuilder: (context, imageError, stackTrace) => error,
        );
      },
    );
  }

  bool get _hasPendingReset => _pendingResetRequest?.isPending == true;

  bool get _pendingResetRequestedByCurrentUser {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return myUid.isNotEmpty && _pendingResetRequest?.requestedBy == myUid;
  }

  String get _pendingVaultUploadKey =>
      SecretVaultUploadIdentity.scopeKey(_vaultUid, _vaultHouseId);

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

  Future<void> _promptPendingVaultUploadRetryIfNeeded() async {
    if (_didPromptPendingVaultUploadRetry || !_encryptionReady || !mounted) {
      return;
    }
    final hasPending = await _hasPendingVaultUploadRecord(
      _pendingVaultUploadKey,
    );
    if (!hasPending || !mounted) {
      return;
    }
    _didPromptPendingVaultUploadRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      SLToast.show(
        context,
        context.tr('util_lnuploadkh_6efff4'),
        actionLabel: context.tr('util_thli_4dffdf'),
        onAction: () {
          unawaited(_retryPendingVaultUpload());
        },
        variant: SLToastVariant.warning,
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
        SLToast.info(context, context.tr('util_khngcnnhct_6c1d76'));
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
    if (_isPreparingVault || !_vaultScopeCanPrepare) return;
    final generation = _vaultMediaGeneration;
    bool isCurrentPreparation() =>
        _vaultScopeCanPrepare && generation == _vaultMediaGeneration;
    if (mounted) {
      _safeSetState(() => _isPreparingVault = true);
    } else {
      _isPreparingVault = true;
    }
    if (!ConnectivityService().isOnline) {
      if (mounted) {
        _safeSetState(() {
          _encryptionReady = false;
          _encStatusMsg = L10nService().translate('vault_no_connection');
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
      // Không đọc metadata/listener trước khi UID và token đã sẵn sàng.
      await _readVaultWithAuthRetry('session', () async {});
      if (!isCurrentPreparation()) return;
      if (_resetRequestSub == null) _listenResetRequest();

      // 1. Thử khôi phục key từ bộ nhớ đệm (nếu app chưa bị đóng và chưa hết timeout)
      final restored = await _enc
          .tryRestoreKeyFromSecureStorage(widget.houseId)
          .timeout(_vaultPrepareTimeout);
      if (!isCurrentPreparation()) return;
      if (restored && mounted) {
        final hasRecoveryCode = await _readVaultWithAuthRetry(
          'recovery-code',
          () => _enc.hasRecoveryCode(widget.houseId),
        );
        if (!isCurrentPreparation()) return;
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
      final hasSetup = await _readVaultWithAuthRetry(
        'passphrase-setup',
        () => _enc.hasPassphraseSetup(widget.houseId),
      );
      if (!isCurrentPreparation()) return;
      final passphrase = await _showPassphraseDialog(hasSetup: hasSetup);
      if (!isCurrentPreparation()) return;
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
        if (!isCurrentPreparation() || recoveryCode == null) return;
        _safeSetState(() {
          _encryptionReady = false;
          _encStatusMsg = context.tr('util_angxcthcmk_ba443e');
        });
        await _readVaultWithAuthRetry(
          'unlock-recovery-code',
          () => _enc.unlockHouseKeyWithRecoveryCode(
            widget.houseId,
            recoveryCode,
          ),
        );
        if (!isCurrentPreparation()) return;
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

      await _readVaultWithAuthRetry(
        'unlock-passphrase',
        () => _enc.unlockHouseKey(widget.houseId, passphrase),
      );
      if (isCurrentPreparation()) {
        final recoveryCode = await _readVaultWithAuthRetry(
          'create-recovery-code',
          () => _enc.createRecoveryCodeIfMissing(widget.houseId),
        );
        if (!isCurrentPreparation()) return;
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
            message: context.tr('util_lumnyniant_6e9a93'),
          );
        }
      }
      if (!isCurrentPreparation()) return;
      _loadPhotos();
      unawaited(_promptPendingVaultUploadRetryIfNeeded());
    } on TimeoutException {
      debugPrint('Secret vault prepare failed: timeout');
      if (isCurrentPreparation()) {
        _safeSetState(() {
          _encryptionReady = false;
          _encStatusMsg = context.tr('util_thaotcmkho_721330');
        });
      }
    } catch (e) {
      if (e is FirebaseException) {
        debugPrint('Secret vault prepare failed: ${e.plugin}/${e.code}');
      } else {
        // Không ghi mật khẩu, recovery code, key hoặc metadata vào log.
        debugPrint('Secret vault prepare failed: ${e.runtimeType}');
      }
      if (isCurrentPreparation()) {
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
    if (!_vaultScopeIsCurrent || !_encryptionReady) return;
    final legacyPasswordRequiredText = context.tr('util_cnnhpmtkhu_b5f391');
    final legacyMigrationText = context.tr('util_cnidungccn_44f5ff');
    final loadFailedText = context.tr('util_khngthtikh_150eff');
    final query = _dbRef
        .child('houses/${widget.houseId}/private_secure')
        .orderByChild('ts')
        .limitToLast(_initialVisiblePhotoLimit);
    try {
      final event = await _readVaultWithAuthRetry('photos', query.get);
      if (!_vaultScopeIsCurrent || !_encryptionReady) return;
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
            final item = Map<String, dynamic>.from(
              Map<dynamic, dynamic>.from(value),
            );
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

        if (!mounted || !_vaultScopeIsCurrent || !_encryptionReady) return;

        if (needsLegacyMigrationLocal) {
          _safeSetState(() => _encStatusMsg = legacyMigrationText);
        }

        loaded.sort(_compareVaultPhotos);
        if (mounted) {
          final oldestTs = loaded.isEmpty
              ? null
              : (loaded.last['ts'] as num?)?.toInt();
          final oldestId = loaded.isEmpty
              ? null
              : loaded.last['id']?.toString();
          _safeSetState(() {
            _photos = loaded;
            _oldestLoadedPhotoTs = oldestTs;
            _oldestLoadedPhotoId = oldestId;
            _hasMorePhotos = loaded.length >= _initialVisiblePhotoLimit;
            _isLoadingMorePhotos = false;
          });
        }
      } else {
        if (mounted) {
          _safeSetState(() {
            _photos = [];
            _oldestLoadedPhotoTs = null;
            _oldestLoadedPhotoId = null;
            _hasMorePhotos = false;
            _isLoadingMorePhotos = false;
          });
        }
      }
    } catch (error) {
      debugPrint(
        'Secret vault load failed: ${AppErrorMapper.resolve(error, fallbackMessage: loadFailedText).message}',
      );
      if (mounted) {
        SLToast.error(
          context,
          L10nService().format('vault_load_image_error', {'error': '$error'}),
        );
        _safeSetState(() => _isLoadingMorePhotos = false);
      }
    }
  }

  void _loadMorePhotos() async {
    if (!_vaultScopeIsCurrent ||
        !_encryptionReady ||
        _isLoadingMorePhotos ||
        !_hasMorePhotos) {
      return;
    }
    final legacyPasswordRequiredText = context.tr('util_cnnhpmtkhu_b5f391');
    _safeSetState(() {
      _isLoadingMorePhotos = true;
    });
    final oldestTs = _oldestLoadedPhotoTs;
    final oldestId = _oldestLoadedPhotoId;
    if (oldestTs == null) {
      if (mounted) {
        _safeSetState(() => _isLoadingMorePhotos = false);
      }
      return;
    }
    try {
      final snapshot = await _readVaultWithAuthRetry(
        'photos-page',
        () => _dbRef
            .child('houses/${widget.houseId}/private_secure')
            .orderByChild('ts')
            .endBefore(oldestTs, key: oldestId)
            .limitToLast(StorageService.secretVaultPageSize)
            .get(),
      );
      if (!_vaultScopeIsCurrent || !_encryptionReady) return;
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
      loadedMore.sort(_compareVaultPhotos);
      if (!mounted || !_vaultScopeIsCurrent || !_encryptionReady) {
        return;
      }
      if (needsLegacyMigrationLocal) {
        _encStatusMsg = context.tr('util_cnidungccn_44f5ff');
      }
      final existingIds = _photos.map((item) => item['id']).toSet();
      final mergedMore = loadedMore
          .where((item) => !existingIds.contains(item['id']))
          .toList(growable: false);
      final nextPhotos = <Map<String, dynamic>>[..._photos, ...mergedMore];
      final nextOldestTs = nextPhotos.isEmpty
          ? null
          : (nextPhotos.last['ts'] as num?)?.toInt();
      final nextOldestId = nextPhotos.isEmpty
          ? null
          : nextPhotos.last['id']?.toString();
      _safeSetState(() {
        _photos = nextPhotos;
        _oldestLoadedPhotoTs = nextOldestTs;
        _oldestLoadedPhotoId = nextOldestId;
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
    if (!_vaultScopeIsCurrent || _isLoading) return;
    if (!_encryptionReady) {
      SLToast.warning(context, context.tr('util_vuilngmkha_19eeeb'));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final pendingKey = _pendingVaultUploadKey;
    if (presetImages == null &&
        await _hasPendingVaultUploadRecord(pendingKey)) {
      if (_vaultScopeIsCurrent) await _retryPendingVaultUpload();
      return;
    }
    final images =
        presetImages ??
        await _storageService.pickImages(
          limit: StorageService.maxSecretVaultSelectionPerBatch,
        );
    if (images.isEmpty || !_vaultScopeIsCurrent) return;

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
              fillColor: _vaultField,
              hintStyle: const TextStyle(color: _vaultTextHint),
              labelStyle: const TextStyle(color: _vaultTextSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _vaultBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _vaultBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: _vaultBorderFocus,
                  width: 2,
                ),
              ),
            ),
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocalState) => SLAlertDialog(
              scrollable: true,

              title: Text(context.tr('util_thmghichty_5651be')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: captionCtrl,
                    style: const TextStyle(
                      color: SLColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLength: 1000,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: SLDialogStyle.field,
                      hintText: context.tr('util_mtkhonhkhc_52663c'),
                      hintStyle: const TextStyle(
                        color: SLDialogStyle.secondary,
                      ),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: SLDialogStyle.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: SLDialogStyle.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: SLDialogStyle.primary,
                          width: 2,
                        ),
                      ),
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
                          checkColor: SLDialogStyle.surface,
                          activeColor: SLDialogStyle.primary,
                          side: const BorderSide(
                            color: SLDialogStyle.secondary,
                          ),
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
                              color: SLDialogStyle.secondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                SLDialogAction(
                  onPressed: () {
                    if (dontAskAgain) {
                      prefs.setInt(
                        skipDialogKey,
                        DateTime.now().millisecondsSinceEpoch +
                            2 * 60 * 60 * 1000,
                      );
                    }
                    Navigator.pop(ctx, '');
                  },
                  child: Text(context.tr('util_bqua_874b71')),
                ),
                SLDialogAction(
                  primary: true,

                  onPressed: () {
                    if (dontAskAgain) {
                      prefs.setInt(
                        skipDialogKey,
                        DateTime.now().millisecondsSinceEpoch +
                            2 * 60 * 60 * 1000,
                      );
                    }
                    Navigator.pop(ctx, captionCtrl.text.trim());
                  },
                  child: Text(context.tr('util_thm_56ef2c')),
                ),
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
        encryptedCaption = await _enc.encryptMessage(
          widget.houseId,
          captionPlain,
        );
      }
      if (!_vaultScopeIsCurrent) return;
      await _savePendingVaultUpload(
        imagePaths: images.map((image) => image.path).toList(growable: false),
        encryptedCaption: encryptedCaption,
      );

      int successCount = 0;
      for (final image in images) {
        if (!_vaultScopeIsCurrent) return;
        final requestId = await _pendingVaultRequestId(pendingKey, image.path);
        if (!_vaultScopeIsCurrent) return;
        final upload = await _storageService.uploadSecretVaultImage(
          widget.houseId,
          image,
          requestId: requestId,
          encryptedCaption: encryptedCaption,
        );
        if (!_vaultScopeIsCurrent) return;
        if (upload?.mediaId?.isNotEmpty == true) {
          successCount++;
          await _removePendingVaultUploadedImageRecord(
            pendingKey: pendingKey,
            imagePath: image.path,
          );
        }
      }
      if (_vaultScopeIsCurrent) await _loadPhotos();

      if (mounted && successCount > 0) {
        SLToast.success(
          context,
          L10nService().format('vault_added_success', {'count': successCount}),
        );
      }
    } catch (e, stack) {
      debugPrint('Vault upload error: $e\n$stack');
      if (mounted) {
        SLToast.error(
          context,
          e is FirebaseFunctionsException && e.code == 'resource-exhausted'
              ? context.tr('vault_storage_limit')
              : L10nService().format('vault_upload_error', {
                  'error': AppErrorMapper.resolve(e).message,
                }),
        );
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

    if (!_vaultScopeIsCurrent || _isLoading) return;
    final deletedHistoryText = context.tr('util_xamtnhring_66ec90');
    final deletedTitle = context.tr('util_xanhringt_8778f3');
    final deletedSourceLabel = context.tr('util_khobmt_e05057');
    final historyHouseId = _vaultHouseId;
    _safeSetState(() => _isLoading = true);
    try {
      final mediaDeleted = await _storageService.deleteSecretVaultFileByPath(
        houseId: widget.houseId,
        mediaId: id,
        storagePath: photo['storagePath']?.toString() ?? '',
      );
      if (!mediaDeleted) throw StateError('Secret Vault deletion failed');
      if (!_vaultScopeIsCurrent) return;
      _clearVaultMediaCache();
      await _loadPhotos();
      if (!_vaultScopeIsCurrent) return;
      // Object đã xóa không có payload khôi phục; tuyệt đối không ghi caption_plain.
      await ActivityHistoryService.instance.add(
        deletedHistoryText,
        houseId: historyHouseId,
        title: deletedTitle,
        subtitle: '',
        action: 'delete',
        module: 'secret_vault',
        entityType: 'secret_photo',
        entityId: id,
        sourceLabel: deletedSourceLabel,
        previewType: 'private',
      );
    } catch (error) {
      if (mounted && _vaultScopeIsCurrent) {
        SLToast.error(context, AppErrorMapper.resolve(error).message);
      }
    } finally {
      if (mounted) _safeSetState(() => _isLoading = false);
    }
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
            fillColor: _vaultField,
            hintStyle: const TextStyle(color: _vaultTextHint),
            labelStyle: const TextStyle(color: _vaultTextSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _vaultBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _vaultBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _vaultBorderFocus, width: 2),
            ),
          ),
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocalState) => VaultAccessSurface(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            scrollable: true,

            title: Text(
              hasSetup
                  ? context.tr('util_mkhakhomt_421171')
                  : context.tr('util_thitlpkhom_792656'),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppHelpButton(articleId: 'security'),
                  Text(
                    hasSetup
                        ? context.tr('util_nhpmtkhukh_e4639a')
                        : context.tr('util_tomtkhukho_e3de4f'),
                    style: SLTheme.quicksand(color: const Color(0xFF50627B)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passphraseCtrl,
                    obscureText: obscurePass,
                    style: const TextStyle(
                      color: Color(0xFF172642),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLength: 32,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFEAF0F7),
                      hintText: context.tr('util_mtkhutithi_d4f304'),
                      hintStyle: const TextStyle(color: Color(0xFF50627B)),
                      counterText: '',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setLocalState(() => obscurePass = !obscurePass),
                        icon: Icon(
                          obscurePass ? Icons.visibility : Icons.visibility_off,
                          color: const Color(0xFF50627B),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD6E6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD6E6)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2479A8),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  if (!hasSetup) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      style: const TextStyle(
                        color: Color(0xFF172642),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLength: 32,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFEAF0F7),
                        hintText: context.tr('util_nhplimtkhu_eee7a7'),
                        hintStyle: const TextStyle(color: Color(0xFF50627B)),
                        counterText: '',
                        suffixIcon: IconButton(
                          onPressed: () => setLocalState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xFF50627B),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD6E6),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD6E6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF2479A8),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (hasSetup)
                SLDialogAction(
                  onPressed: () => Navigator.pop(ctx, _recoveryAction),
                  child: Text(context.tr('util_dngmkhiphc_698038')),
                ),
              SLDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('util_ng_aecc61')),
              ),
              SLDialogAction(
                primary: true,

                onPressed: () {
                  final passphrase = passphraseCtrl.text.trim();
                  final confirm = confirmCtrl.text.trim();
                  if (passphrase.length < 8) {
                    SLToast.error(
                      context,
                      context.tr('util_mtkhukhomt_e98699'),
                    );
                    return;
                  }
                  if (!hasSetup && passphrase != confirm) {
                    SLToast.error(
                      context,
                      context.tr('util_mtkhunhpli_f31f82'),
                    );
                    return;
                  }
                  Navigator.pop(ctx, passphrase);
                },
                child: Text(
                  hasSetup
                      ? context.tr('util_mkha_e16936')
                      : context.tr('util_thitlp_486746'),
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
            fillColor: _vaultField,
            hintStyle: const TextStyle(color: _vaultTextHint),
            labelStyle: const TextStyle(color: _vaultTextSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _vaultBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _vaultBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _vaultBorderFocus, width: 2),
            ),
          ),
        ),
        child: VaultAccessSurface(
          title: Text(context.tr('util_nhpmkhiphc_44a271')),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: SLColors.ink,
              fontWeight: FontWeight.w600,
            ),
            maxLength: 30,
            decoration: InputDecoration(
              filled: true,
              fillColor: SLDialogStyle.field,
              hintText: L10nService().translate('vault_code_placeholder'),
              hintStyle: const TextStyle(color: SLDialogStyle.secondary),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            SLDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('util_ng_f63d1e')),
            ),
            SLDialogAction(
              primary: true,

              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(context.tr('util_mkho_68a790')),
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
      builder: (ctx) => SLAlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: SLTheme.quicksand(color: SLDialogStyle.secondary),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SLDialogStyle.field,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SLDialogStyle.border),
              ),
              child: SelectableText(
                recoveryCode,
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                  color: SLDialogStyle.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          SLDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recoveryCode));
              if (!mounted) return;
              SLToast.success(context, context.tr('util_saochpmkhi_b1f0e5'));
            },
            child: Text(context.tr('util_saochp_cbfba9')),
          ),
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('util_tilu_7a1601')),
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
      SLToast.error(
        context,
        AppErrorMapper.resolve(
          e,
          fallbackMessage: context.tr('util_chathtolim_b5c569'),
        ).message,
      );
    }
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _vaultBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _vaultBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: _vaultAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          context.tr('auto_lock_after'),
                          style: SLTheme.quicksand(
                            color: _vaultTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<UiPrefsState>(
                      valueListenable: UiPrefs.notifier,
                      builder: (context, uiState, _) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [0, 1, 5, 15, 60].map((m) {
                              final isSel = uiState.vaultTimeoutMins == m;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    m == 0
                                        ? context.tr('home_tcth_3c4371')
                                        : L10nScope.of(context).format(
                                            'ui_utilities_value1_minutes_eba409',
                                            {'value1': m},
                                          ),
                                  ),
                                  selected: isSel,
                                  selectedColor: _vaultAccent,
                                  labelStyle: SLTheme.quicksand(
                                    color: isSel
                                        ? _vaultBg
                                        : _vaultTextSecondary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                  backgroundColor: _vaultField,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(color: _vaultBorder),
                                  onSelected: (s) {
                                    if (s) {
                                      UiPrefs.saveState(
                                        uiState.copyWith(vaultTimeoutMins: m),
                                      );
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.style_outlined, color: _vaultAccent),
                title: Text(
                  context.tr('vault_style_title'),
                  style: SLTheme.quicksand(color: _vaultTextPrimary),
                ),
                subtitle: ValueListenableBuilder<UiPrefsState>(
                  valueListenable: UiPrefs.notifier,
                  builder: (context, uiState, _) {
                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: uiState.vaultHomeStyle,
                        isExpanded: true,
                        dropdownColor: _vaultBgAlt,
                        style: SLTheme.quicksand(
                          color: _vaultAccent,
                          fontWeight: FontWeight.w700,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: _vaultTextSecondary,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'soft',
                            child: Text(context.tr('vault_style_soft')),
                          ),
                          DropdownMenuItem(
                            value: 'secure',
                            child: Text(context.tr('vault_style_secure')),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            UiPrefs.saveState(
                              uiState.copyWith(vaultHomeStyle: val),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: _vaultBorder),
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
                  style: SLTheme.quicksand(color: _vaultTextPrimary),
                ),
                subtitle: Text(
                  _hasPendingReset
                      ? L10nService().format('vault_scheduled_deletion', {
                          'time': _formatResetSchedule(
                            _pendingResetRequest?.scheduledAt ?? 0,
                          ),
                        })
                      : context.tr('util_xcnhnquaem_043f1a'),
                  style: SLTheme.quicksand(color: _vaultTextSecondary),
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
                leading: const Icon(Icons.lock_reset, color: _vaultAccent),
                title: Text(
                  context.tr('util_imtkhu_ff6fe7'),
                  style: SLTheme.quicksand(color: _vaultTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChangePasswordDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.key_rounded, color: _vaultAccent),
                title: Text(
                  _hasRecoveryCode
                      ? context.tr('util_tolimkhiph_6a2c38')
                      : context.tr('util_tomkhiphc_67ed4c'),
                  style: SLTheme.quicksand(color: _vaultTextPrimary),
                ),
                subtitle: Text(
                  _hasRecoveryCode
                      ? context.tr('util_mymicthdng_fa5403')
                      : context.tr('util_nntotrnhmt_9b80a1'),
                  style: SLTheme.quicksand(color: _vaultTextSecondary),
                ),
                onTap: _handleRegenerateRecoveryCode,
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: SLColors.warning),
                title: Text(
                  context.tr('util_khalikhomt_c053ec'),
                  style: SLTheme.quicksand(color: SLColors.warning),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _enc.clearCache(widget.houseId);
                  _clearVaultMediaCache();
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
            fillColor: _vaultField,
            hintStyle: const TextStyle(color: _vaultTextHint),
            labelStyle: const TextStyle(color: _vaultTextSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _vaultBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _vaultBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _vaultBorderFocus, width: 2),
            ),
          ),
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocalState) => SLAlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            scrollable: true,

            title: Text(context.tr('util_imtkhu_ff6fe7')),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: obscureOld,
                    style: const TextStyle(
                      color: SLColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLength: 32,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: SLDialogStyle.field,
                      labelText: context.tr('util_mtkhuc_36b0a2'),
                      labelStyle: const TextStyle(
                        color: SLDialogStyle.secondary,
                      ),
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld ? Icons.visibility : Icons.visibility_off,
                          color: SLDialogStyle.secondary,
                        ),
                        onPressed: () =>
                            setLocalState(() => obscureOld = !obscureOld),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    style: const TextStyle(
                      color: SLColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLength: 32,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: SLDialogStyle.field,
                      labelText: context.tr('util_mtkhumi_ccef95'),
                      labelStyle: const TextStyle(
                        color: SLDialogStyle.secondary,
                      ),
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility : Icons.visibility_off,
                          color: SLDialogStyle.secondary,
                        ),
                        onPressed: () =>
                            setLocalState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscureNew,
                    style: const TextStyle(
                      color: SLColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLength: 32,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: SLDialogStyle.field,
                      labelText: context.tr('util_nhplimtkhu_82a9a4'),
                      labelStyle: const TextStyle(
                        color: SLDialogStyle.secondary,
                      ),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                        child: Text(
                          context.tr('util_tiqunmtkhu_e343b1'),
                          style: SLTheme.quicksand(
                            color: SLDialogStyle.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              SLDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('util_hy_1e4050')),
              ),
              SLDialogAction(
                primary: true,

                onPressed: () async {
                  final oldPass = oldPassCtrl.text.trim();
                  final newPass = newPassCtrl.text.trim();
                  final confirm = confirmCtrl.text.trim();

                  if (oldPass.isEmpty || newPass.isEmpty) return;
                  if (newPass.length < 8) {
                    SLToast.show(context, context.tr('util_mtkhumiphi_0da717'));
                    return;
                  }
                  if (newPass != confirm) {
                    SLToast.show(context, context.tr('util_mtkhumicha_83d367'));
                    return;
                  }

                  _safeSetState(() {
                    _encryptionReady = false;
                    _encStatusMsg = context.tr('util_angimtkhuv_db04a3');
                  });
                  Navigator.pop(ctx);

                  try {
                    await _enc.changePassphrase(
                      widget.houseId,
                      oldPass,
                      newPass,
                    );
                    final recoveryCode = await _enc.createRecoveryCodeIfMissing(
                      widget.houseId,
                    );
                    if (mounted) {
                      _safeSetState(() {
                        _encryptionReady = true;
                        _encStatusMsg = context.tr('util_imtkhuthnh_82a076');
                        _hasRecoveryCode = true;
                      });
                      SLToast.success(
                        context,
                        context.tr('util_imtkhuthnh_e54dc2'),
                      );
                      if (recoveryCode != null) {
                        await _showGeneratedRecoveryCodeDialog(
                          recoveryCode,
                          title: context.tr('util_mkhiphcmi_44cc09'),
                          message: context.tr('util_mtkhuinnmk_e727c7'),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      _safeSetState(() {
                        _encryptionReady = true;
                        _encStatusMsg = context.tr('util_khomtm_a6c43e');
                      });
                      SLToast.error(
                        context,
                        context.tr('util_mtkhucchan_decb9b'),
                      );
                    }
                  }
                },
                child: Text(context.tr('util_imtkhu_82844c')),
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
      builder: (ctx) => SLAlertDialog(
        title: Text(
          _hasPendingReset
              ? context.tr('util_yucureseta_74986f')
              : context.tr('util_resetkhonh_c48d2d'),
        ),
        content: Text(
          _hasPendingReset
              ? L10nService().format('vault_scheduled_deletion_full', {
                  'time': _formatResetSchedule(
                    _pendingResetRequest?.scheduledAt ?? 0,
                  ),
                  'after': context.tr('util_trongthigi_6645aa'),
                })
              : '${context.tr('util_resetkhonh_d0b294')}${context.tr('util_bnphixcnhn_b3fe0e')}${isWithin12Hours ? context.tr('vault_recent_password_reset_wait') : ''}',
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('util_hu_9daba0')),
          ),
          SLDialogAction(
            primary: true,

            onPressed: () {
              Navigator.pop(ctx);
              if (_hasPendingReset) {
                _cancelVaultResetRequest();
              } else {
                _startVaultResetRequestFlow();
              }
            },
            child: Text(
              _hasPendingReset
                  ? context.tr('util_thuhiyucu_cc5144')
                  : context.tr('util_xcnhnquaem_645252'),
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
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('util_khiphckhom_4fc524')),
        content: Text(
          isWithin12Hours
              ? context.tr('util_vbnthitlpm_b25608')
              : L10nService().translate('vault_reset_warning'),
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('util_hy_1e4050')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,

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
                      _encStatusMsg = context.tr('util_khomtcrese_b11161');
                      _hasRecoveryCode = false;
                      // Không clear _photos, giữ nguyên dữ liệu trên UI
                    });
                    SLToast.success(
                      context,
                      context.tr('util_resetmtkhu_02f484'),
                    );
                  }
                } else {
                  await _enc.resetVault(widget.houseId);
                  if (mounted) {
                    _safeSetState(() {
                      _encStatusMsg = context.tr('util_khomtcrese_aee917');
                      _photos = [];
                      _hasRecoveryCode = false;
                    });
                    SLToast.warning(
                      context,
                      context.tr('util_xakhomtchy_906978'),
                    );
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
            child: Text(
              isWithin12Hours
                  ? context.tr('util_tiptc_555f1f')
                  : context.tr('util_xavtoli_90b1ee'),
            ),
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
            color: _vaultTextPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: _vaultBg.withValues(alpha: 0.92)),
          ),
        ),
        leading: IconButton(
          tooltip: context.tr('p3_back'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _vaultTextSecondary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: _vaultTextSecondary,
              size: 22,
            ),
            tooltip: context.tr('help_security_title'),
            onPressed: () => showAppHelpArticle(context, 'security'),
          ),
          if (_encryptionReady)
            IconButton(
              icon: const Icon(Icons.settings, color: _vaultTextSecondary),
              onPressed: () => _showSettingsModal(),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_vaultBg, Color(0xFF101D33), _vaultBg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: VaultGalleryLayout(
            header: Column(
              children: [
                _buildEncryptionBadge(),
                _buildPendingResetBanner(),
                _buildUploadHeader(),
              ],
            ),
            gallerySlivers: _buildPhotoSlivers(),
          ),
        ),
      ),
    );
  }
}
