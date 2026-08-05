// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/services/l10n_service.dart';
import '../../utils/services/auth_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/secure_storage_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/offline_cache_service.dart';
import '../../utils/flexible_date_input.dart';
import '../app_entry.dart';
import 'dart:ui';
import '../app_entry/widgets/loading_scaffold.dart';
import 'widgets/gender_selection_dialog.dart';
import 'widgets/relationship_mode_dialog.dart';
import 'login_screen.dart';
import '../../core/sl_theme.dart';
import '../../core/fast_backdrop_filter.dart';

class HouseOnboardingScreen extends StatefulWidget {
  final String? initialMode;
  final String? initialRole;
  final String? initialHouseName;
  final String? initialRecoveryQuestion;
  final String? initialRecoveryAnswer;
  final bool autoCreateOnly;
  final Future<void> Function()? onHouseCreated;
  final Future<void> Function()? onSignedOut;

  const HouseOnboardingScreen({
    super.key,
    this.initialMode,
    this.initialRole,
    this.initialHouseName,
    this.initialRecoveryQuestion,
    this.initialRecoveryAnswer,
    this.autoCreateOnly = false,
    this.onHouseCreated,
    this.onSignedOut,
  });

  @override
  State<HouseOnboardingScreen> createState() => _HouseOnboardingScreenState();
}

class _HouseOnboardingScreenState extends State<HouseOnboardingScreen> {
  String _defaultHouseName() =>
      L10nService().translate('onboarding_default_house_name');
  static const String _savedGenderPrefsKey = 'il_saved_gender';
  static const String _pendingSignupRecoveryQuestionPrefsKey =
      'il_pending_signup_recovery_question';
  static const String _pendingSignupRecoveryAnswerPrefsKey =
      'il_pending_signup_recovery_answer';
  static const String _pendingSignupAutoCreateHousePrefsKey =
      'il_pending_signup_auto_create_house';

  final _houseService = HouseService();
  final _authService = AuthService();
  final _houseNameCtrl = TextEditingController();
  final _recoveryACtrl = TextEditingController();
  final _customIdCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  String _customId = '';
  bool _isIdChecking = false;
  bool _isIdAvailable = false;
  String? _idErrorReason;
  List<String> _idSuggestions = [];
  final bool _showCustomIdScreen = false;

  bool _isLoading = false;
  String _mode = 'couple';
  bool _hasResolvedRelationshipMode = false;
  String? _cachedRole;
  bool _enableRecovery = false;
  bool _showScrollHint = false;
  bool _dismissedScrollHint = false;
  bool _isPromptingCreationSetup = false;

  final bool _showLegacyIntro = false;
  Timer? _scrollHintTimer;
  String? _autoCreateFailureMessage;
  String? _autoCreateFailureDetail;
  int _authSyncRetryCount = 0;
  int _transientCreateRetryCount = 0;
  String _selectedSecurityQuestion =
      L10nService().translate('Ngày sinh của bạn?');

  final List<String> _securityQuestions = [
    L10nService().translate('Ngày sinh của bạn?'),
    L10nService().translate('Con vật đầu tiên bạn nuôi?'),
    L10nService().translate('Tên giáo viên chủ nhiệm lớp 1?'),
    L10nService().translate('Nơi lần đầu tiên hai bạn gặp nhau?'),
    L10nService().translate('Món ăn yêu thích nhất của bạn?'),
  ];

  @override
  void initState() {
    super.initState();

    final initialMode =
        _authService.normalizeRelationshipMode(widget.initialMode);
    if (initialMode != null) {
      _mode = initialMode;
      _hasResolvedRelationshipMode = true;
    } else {
      _hydrateStoredMode();
    }
    _cachedRole = _normalizeRole(widget.initialRole);

    final houseName = (widget.initialHouseName ?? '').trim();
    if (houseName.isNotEmpty) {
      _houseNameCtrl.text = houseName;
    } else if (widget.autoCreateOnly) {
      _houseNameCtrl.text = _defaultHouseName();
    }

    final question = (widget.initialRecoveryQuestion ?? '').trim();
    final answer = (widget.initialRecoveryAnswer ?? '').trim();
    if (question.isNotEmpty && answer.isNotEmpty) {
      _enableRecovery = true;
      if (_securityQuestions.contains(question)) {
        _selectedSecurityQuestion = question;
      }
      _recoveryACtrl.text = answer;
    }

    _hydratePendingSignupDraft();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleScrollHint();
    });
  }

  Future<void> _hydrateStoredMode() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMode =
        _authService.normalizeRelationshipMode(prefs.getString('il_rel_mode'));
    final storedRole = _normalizeRole(prefs.getString('il_role'));

    if (mounted) {
      setState(() {
        if (storedMode != null) {
          _mode = storedMode;
          _hasResolvedRelationshipMode = true;
        }
        if (storedRole != null) {
          _cachedRole = storedRole;
        }
      });
    }
  }

  Future<void> _hydratePendingSignupDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final hasExplicitRecoveryDraft =
        (widget.initialRecoveryQuestion ?? '').trim().isNotEmpty &&
            (widget.initialRecoveryAnswer ?? '').trim().isNotEmpty;
    final hasExplicitMode =
        _authService.normalizeRelationshipMode(widget.initialMode) != null;
    final hasExplicitRole = _normalizeRole(widget.initialRole) != null;
    await _hydrateMissingCreationPrerequisites(
      prefs: prefs,
      allowMode: !hasExplicitMode,
      allowRole: !hasExplicitRole,
    );
    if (!mounted) return;
    final storedMode =
        _authService.normalizeRelationshipMode(prefs.getString('il_rel_mode'));
    final storedRole = _normalizeRole(prefs.getString('il_role'));
    final pendingQuestion =
        prefs.getString(_pendingSignupRecoveryQuestionPrefsKey)?.trim() ?? '';
    final pendingAnswer =
        prefs.getString(_pendingSignupRecoveryAnswerPrefsKey)?.trim() ?? '';
    final shouldAutoCreate =
        prefs.getBool(_pendingSignupAutoCreateHousePrefsKey) ?? false;

    if (!mounted) return;

    if (!hasExplicitRecoveryDraft &&
        pendingQuestion.isNotEmpty &&
        pendingAnswer.isNotEmpty) {
      setState(() {
        if (!hasExplicitMode && storedMode != null) {
          _mode = storedMode;
          _hasResolvedRelationshipMode = true;
        }
        if (!hasExplicitRole && storedRole != null) {
          _cachedRole = storedRole;
        }
        _enableRecovery = true;
        if (_securityQuestions.contains(pendingQuestion)) {
          _selectedSecurityQuestion = pendingQuestion;
        }
        _recoveryACtrl.text = pendingAnswer;
      });
    } else if ((!hasExplicitMode && storedMode != null) ||
        (!hasExplicitRole && storedRole != null)) {
      setState(() {
        if (!hasExplicitMode && storedMode != null) {
          _mode = storedMode;
          _hasResolvedRelationshipMode = true;
        }
        if (!hasExplicitRole && storedRole != null) {
          _cachedRole = storedRole;
        }
      });
    }

    if (widget.autoCreateOnly || shouldAutoCreate) {
      if (shouldAutoCreate) {
        await prefs.remove(_pendingSignupAutoCreateHousePrefsKey);
      }
      if (_houseNameCtrl.text.trim().isEmpty) {
        _houseNameCtrl.text = _defaultHouseName();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _isLoading) return;
        try {
          final existingHouseId =
              await _houseService.getCurrentHouseId(preferFresh: true);
          if (existingHouseId != null && existingHouseId.isNotEmpty) {
            debugPrint(
              '[HouseOnboarding] autoCreateOnly found existing house: $existingHouseId',
            );
            if (widget.onHouseCreated != null) {
              await widget.onHouseCreated!.call();
              return;
            }
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AppEntry()),
                (route) => false,
              );
            }
            return;
          }
        } catch (_) {}

        debugPrint('[HouseOnboarding] autoCreateOnly -> _createHouse queued');
        _createHouse();
      });
      return;
    }
  }

  Future<void> _clearPendingSignupDraft({
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await resolvedPrefs.remove(_pendingSignupRecoveryQuestionPrefsKey);
    await resolvedPrefs.remove(_pendingSignupRecoveryAnswerPrefsKey);
    await resolvedPrefs.remove(_pendingSignupAutoCreateHousePrefsKey);
  }

  @override
  void dispose() {
    _scrollHintTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _houseNameCtrl.dispose();
    _recoveryACtrl.dispose();
    _customIdCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onIdChanged(String val) {
    final clean = val.trim().toUpperCase();
    _customId = clean;
    _isIdAvailable = false;
    _idErrorReason = null;
    _idSuggestions = [];

    _debounceTimer?.cancel();
    if (clean.isEmpty) {
      setState(() {});
      return;
    }

    if (!RegExp(r'^[A-Z0-9_]{3,20}$').hasMatch(clean)) {
      setState(() {
        _idErrorReason = 'Mã chỉ gồm chữ, số, dấu gạch dưới (3-20 ký tự).';
      });
      return;
    }

    setState(() {
      _isIdChecking = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await _houseService.checkHouseIdAvailability(clean);
        if (!mounted || _customId != clean) return;

        setState(() {
          _isIdChecking = false;
          _isIdAvailable = res['available'] == true;
          if (!_isIdAvailable) {
            _idErrorReason =
                res['reason'] ?? 'Mã nhà đã tồn tại, vui lòng chọn mã khác.';
            final suggs = res['suggestions'];
            if (suggs is List) {
              _idSuggestions = suggs.map((e) => e.toString()).toList();
            }
          }
        });
      } catch (e) {
        if (!mounted || _customId != clean) return;
        setState(() {
          _isIdChecking = false;
          _idErrorReason = 'Lỗi kết nối máy chủ.';
        });
      }
    });
  }

  void _selectSuggestion(String suggestion) {
    _customIdCtrl.text = suggestion;
    _onIdChanged(suggestion);
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.offset > 24 &&
        !_dismissedScrollHint) {
      _dismissedScrollHint = true;
    }

    if (_showScrollHint && mounted) {
      setState(() => _showScrollHint = false);
    }

    _scheduleScrollHint();
  }

  void _scheduleScrollHint() {
    _scrollHintTimer?.cancel();
    if (_dismissedScrollHint) return;

    _scrollHintTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final canScrollMore = position.maxScrollExtent - position.pixels > 120;
      if (!canScrollMore) return;
      setState(() => _showScrollHint = true);
    });
  }

  bool _isBirthQuestion(String question) {
    return DateInputUtils.looksLikeBirthQuestion(question);
  }

  void _normalizeRecoveryBirthAnswer() {
    final normalized = DateInputUtils.normalizeForDisplay(
      _recoveryACtrl.text,
      firstYear: 1900,
      lastYear: DateTime.now().year,
      allowMissingYear: true,
    );
    _recoveryACtrl.text = normalized;
    _recoveryACtrl.selection =
        TextSelection.collapsed(offset: normalized.length);
  }

  String? _normalizeRole(String? role) {
    final normalized = role?.trim();
    if (normalized == 'user1' || normalized == 'user2') {
      return normalized;
    }
    return null;
  }

  String? _resolveSavedRoleFromPrefs(
    SharedPreferences prefs, {
    String? email,
  }) {
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    final emailScopedRole = normalizedEmail.isEmpty
        ? null
        : _normalizeRole(
            prefs.getString('${_savedGenderPrefsKey}_$normalizedEmail'),
          );
    return emailScopedRole ??
        _normalizeRole(prefs.getString(_savedGenderPrefsKey));
  }

  Future<void> _hydrateMissingCreationPrerequisites({
    SharedPreferences? prefs,
    bool allowMode = true,
    bool allowRole = true,
  }) async {
    if (!allowMode && !allowRole) return;

    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim().toLowerCase();

    String? resolvedMode;
    if (allowMode) {
      resolvedMode = _authService.normalizeRelationshipMode(
        resolvedPrefs.getString('il_rel_mode'),
      );
      resolvedMode ??= _authService.normalizeRelationshipMode(
        await _authService.syncRelationshipModeForCurrentUser(user: user),
      );
      if (resolvedMode != null) {
        await resolvedPrefs.setString('il_rel_mode', resolvedMode);
      }
    }

    String? resolvedRole;
    if (allowRole) {
      resolvedRole = _normalizeRole(resolvedPrefs.getString('il_role'));
      resolvedRole ??= _resolveSavedRoleFromPrefs(
        resolvedPrefs,
        email: email,
      );
      if (resolvedRole != null) {
        await resolvedPrefs.setString('il_role', resolvedRole);
      }
    }

    if (!mounted) return;

    if (resolvedMode != null || resolvedRole != null) {
      setState(() {
        if (resolvedMode != null) {
          _mode = resolvedMode;
          _hasResolvedRelationshipMode = true;
        }
        if (resolvedRole != null) {
          _cachedRole = resolvedRole;
        }
      });
    }
  }

  Future<T?> _showSetupDialogAfterBuild<T>(
    Future<T?> Function() action,
  ) async {
    final completer = Completer<T?>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        completer.complete(null);
        return;
      }
      completer.complete(await action());
    });
    return completer.future;
  }

  Future<void> _persistCreationPrerequisites({
    SharedPreferences? prefs,
    String? relationshipMode,
    String? role,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim().toLowerCase();

    final normalizedMode =
        _authService.normalizeRelationshipMode(relationshipMode);
    if (normalizedMode != null) {
      await resolvedPrefs.setString('il_rel_mode', normalizedMode);
      if (email.isNotEmpty) {
        await resolvedPrefs.setString(
          _authService.relationshipModePrefsKey(email),
          normalizedMode,
        );
      }
      unawaited(
        _authService
            .savePendingRelationshipModeForCurrentUser(normalizedMode)
            .catchError((_) {}),
      );
    }

    final normalizedRole = _normalizeRole(role);
    if (normalizedRole != null) {
      await resolvedPrefs.setString('il_role', normalizedRole);
      await resolvedPrefs.setString(_savedGenderPrefsKey, normalizedRole);
      if (email.isNotEmpty) {
        await resolvedPrefs.setString(
          '${_savedGenderPrefsKey}_$email',
          normalizedRole,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      if (normalizedMode != null) {
        _mode = normalizedMode;
        _hasResolvedRelationshipMode = true;
      }
      if (normalizedRole != null) {
        _cachedRole = normalizedRole;
      }
      if (normalizedMode != null || normalizedRole != null) {
        _autoCreateFailureMessage = null;
      }
    });
  }

  Future<bool> _promptForMissingCreationPrerequisites({
    SharedPreferences? prefs,
  }) async {
    if (_isPromptingCreationSetup) {
      return _creationPrerequisiteErrorMessage() == null;
    }

    try {
      final existingHouseId =
          await _houseService.getCurrentHouseId(preferFresh: true);
      if (existingHouseId != null && existingHouseId.isNotEmpty) {
        debugPrint(
          '[HouseOnboarding] Found existing house during prerequisite check: $existingHouseId',
        );
        final prefs = await OfflineCacheService.getPrefs();
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        await prefs.setString('il_house_id', existingHouseId);
        await prefs.setString('il_auth_uid', currentUid);
        await SecureStorageService.instance
            .write(SecureStorageService.keyHouseId, existingHouseId);
        await SecureStorageService.instance
            .write(SecureStorageService.keyAuthUid, currentUid);
        if (widget.onHouseCreated != null) {
          await widget.onHouseCreated!.call();
        } else if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AppEntry()),
            (route) => false,
          );
        }
        return true;
      }
    } catch (_) {}

    final needsMode = _resolvedRelationshipModeOrNull() == null;
    final needsRole = _resolvedRoleOrNull() == null;
    if (!needsMode && !needsRole) {
      return true;
    }

    _isPromptingCreationSetup = true;
    try {
      if (needsMode) {
        final pickedMode = _authService.normalizeRelationshipMode(
          await _showSetupDialogAfterBuild(
            () => showDialog<String>(
              context: context,
              useRootNavigator: true,
              barrierDismissible: false,
              builder: (dialogContext) => RelationshipModeDialog(
                onSelected: (mode) {
                  if (dialogContext.mounted &&
                      Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop(mode);
                  }
                },
              ),
            ),
          ),
        );
        if (!mounted || pickedMode == null) {
          return false;
        }
        await _persistCreationPrerequisites(
          prefs: prefs,
          relationshipMode: pickedMode,
        );
        if (!mounted) return false;
      }

      if (_resolvedRoleOrNull() == null) {
        final pickedRole = _normalizeRole(
          await _showSetupDialogAfterBuild(
            () => showDialog<String>(
              context: context,
              useRootNavigator: true,
              barrierDismissible: false,
              builder: (dialogContext) => GenderSelectionDialog(
                onSelected: (role) {
                  if (dialogContext.mounted &&
                      Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop(role);
                  }
                },
              ),
            ),
          ),
        );
        if (!mounted || pickedRole == null) {
          return false;
        }
        await _persistCreationPrerequisites(
          prefs: prefs,
          role: pickedRole,
        );
        if (!mounted) return false;
      }

      return _creationPrerequisiteErrorMessage() == null;
    } finally {
      _isPromptingCreationSetup = false;
    }
  }

  String? _resolvedRelationshipModeOrNull() {
    final explicitMode =
        _authService.normalizeRelationshipMode(widget.initialMode);
    if (explicitMode != null) {
      return explicitMode;
    }
    if (_hasResolvedRelationshipMode) {
      return _authService.normalizeRelationshipMode(_mode);
    }
    return null;
  }

  String? _resolvedRoleOrNull() {
    return _normalizeRole(widget.initialRole) ?? _normalizeRole(_cachedRole);
  }

  String? _creationPrerequisiteErrorMessage() {
    final relationshipMode = _resolvedRelationshipModeOrNull();
    final role = _resolvedRoleOrNull();
    if (relationshipMode != null && role != null) {
      return null;
    }
    if (relationshipMode == null && role == null) {
      return L10nService().translate('onboarding_missing_role_and_mode');
    }
    if (relationshipMode == null) {
      return L10nService().translate('onboarding_missing_mode');
    }
    return L10nService().translate('onboarding_missing_role');

    if (role != null) {
      return null;
    }
    if (relationshipMode == null && role == null) {
      return L10nService().translate('onboarding_missing_role_and_mode_logout');
    }
    return L10nService().translate('onboarding_missing_role_logout');
  }

  String _technicalFailureDetail(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return L10nService().translate('onboarding_no_error_code');
    }
    return raw.length > 260 ? '${raw.substring(0, 260)}...' : raw;
  }

  bool _needsEmailVerification(Object? error, String message) {
    final normalized =
        '${message.toLowerCase()} ${error?.toString().toLowerCase() ?? ''}';
    return normalized.contains('resource-exhausted') ||
        normalized.contains('giới hạn') ||
        normalized.contains('too many') ||
        normalized.contains('quá nhiều') ||
        normalized.contains('verify') ||
        normalized.contains('xác minh');
  }

  String _clearCreateFailureMessage(String message, Object? error) {
    final normalized =
        '${message.toLowerCase()} ${error?.toString().toLowerCase() ?? ''}';
    if (normalized.contains('unauthenticated') ||
        normalized.contains('chưa đăng nhập') ||
        normalized.contains('đăng nhập')) {
      return 'Phiên đăng nhập đang đồng bộ. App sẽ tự thử lại, bạn không cần đăng xuất.';
    }
    if (normalized.contains('permission-denied') ||
        normalized.contains('app check') ||
        normalized.contains('debug token') ||
        normalized.contains('play integrity')) {
      return 'Thiết bị đang được xác thực bảo mật. Vui lòng chờ vài giây rồi thử lại.';
    }
    if (_needsEmailVerification(error, message)) {
      return 'Cần xác minh Gmail để tiếp tục tạo nhà.';
    }
    if (normalized.contains('timeout') ||
        normalized.contains('network') ||
        normalized.contains('deadline') ||
        normalized.contains('mạng') ||
        normalized.contains('kết nối')) {
      return 'Mạng hoặc server phản hồi chậm. App sẽ cho thử lại mà không đăng xuất tài khoản.';
    }
    return message;
  }

  Future<void> _sendGmailVerification() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = (user?.email ?? '').trim();
      if (user == null || email.isEmpty) {
        throw Exception(
            'Phiên đăng nhập đang đồng bộ. Vui lòng thử lại sau vài giây.');
      }

      final maskedEmail = _authService.maskEmail(email);
      final otp = await _promptHouseCreationOtp(
        HouseCreationOtpRequiredException(
          maskedEmail: maskedEmail,
          createdCount: 3,
        ),
      );
      if (!mounted) return;
      if (otp == null || otp.trim().isEmpty) {
        return;
      }

      await _createHouse(houseCreationOtp: otp.trim());
    } catch (error) {
      if (!mounted) return;
      _setAutoCreateFailureMessage(
        AppErrorMapper.resolve(error).message,
        error: error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _promptHouseCreationOtp(
    HouseCreationOtpRequiredException gate,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim();
    if (email.isEmpty) {
      _setAutoCreateFailureMessage(
        'Tài khoản cần có Gmail hợp lệ để nhận mã xác minh.',
        error: gate,
      );
      return null;
    }

    try {
      await _authService.sendOtpEmail(email);
    } catch (error) {
      if (!mounted) return null;
      _setAutoCreateFailureMessage(
        AppErrorMapper.resolve(error).message,
        error: error,
      );
      return null;
    }
    if (!mounted) return null;

    var otpValue = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: Color(0xFFD81B60),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Xác minh Gmail',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhập mã xác nhận đã gửi về ${gate.maskedEmail.isNotEmpty ? gate.maskedEmail : email} để tiếp tục tạo nhà.',
                  style: SLTheme.quicksand(
                    color: SLColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6FA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFFD3E4)),
                  ),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Mã Gmail 6 số',
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      otpValue = value.trim();
                      if (otpValue.length == 6) {
                        Navigator.of(dialogContext).pop(otpValue);
                      }
                    },
                    onSubmitted: (_) {
                      if (otpValue.length == 6) {
                        Navigator.of(dialogContext).pop(otpValue);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Để sau',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (otpValue.isNotEmpty) {
                  Navigator.of(dialogContext).pop(otpValue);
                }
              },
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              child: Text(
                'Xác nhận',
                style: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  void _setAutoCreateFailureMessage(String message, {Object? error}) {
    if (!mounted) return;
    final resolvedMessage = _clearCreateFailureMessage(message, error);
    final detail =
        kDebugMode && error != null ? _technicalFailureDetail(error) : null;
    if (_autoCreateFailureMessage == resolvedMessage &&
        _autoCreateFailureDetail == detail) {
      return;
    }
    setState(() {
      _autoCreateFailureMessage = resolvedMessage;
      _autoCreateFailureDetail = detail;
    });
  }

  Future<void> _signOutToLogin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _autoCreateFailureMessage = null;
    });
    try {
      await _clearPendingSignupDraft();
      await _authService.signOut();
      if (!mounted) return;

      if (widget.onSignedOut != null) {
        await widget.onSignedOut!.call();
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      if (widget.autoCreateOnly) {
        _setAutoCreateFailureMessage(
          AppErrorMapper.resolve(
            e,
            fallbackMessage:
                'Không tạo được ngôi nhà: hãy kiểm tra trạng thái đăng nhập và kết nối mạng.',
          ).message,
          error: e,
        );
        return;
      }
      _showError(
        AppErrorMapper.resolve(
          e,
          fallbackMessage:
              'Không đăng xuất được: hãy kiểm tra kết nối mạng hoặc trạng thái đăng nhập hiện tại.',
        ).message,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createHouse(
      {String? houseCreationOtp, String? customHouseId}) async {
    FocusManager.instance.primaryFocus?.unfocus();

    await _hydrateMissingCreationPrerequisites(
      allowMode: _resolvedRelationshipModeOrNull() == null,
      allowRole: _resolvedRoleOrNull() == null,
    );
    if (!mounted) return;

    var missingSetupMessage = _creationPrerequisiteErrorMessage();
    if (missingSetupMessage != null && widget.autoCreateOnly) {
      await _promptForMissingCreationPrerequisites();
      if (!mounted) return;
      missingSetupMessage = _creationPrerequisiteErrorMessage();
    }
    if (missingSetupMessage != null) {
      if (widget.autoCreateOnly) {
        _setAutoCreateFailureMessage(missingSetupMessage);
      } else {
        _showError(missingSetupMessage, title: 'Thiếu thông tin');
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      const expiredSessionMessage =
          'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại để tiếp tục.';
      if (widget.autoCreateOnly) {
        _setAutoCreateFailureMessage(expiredSessionMessage);
      } else {
        _showError(expiredSessionMessage, title: 'Phiên đăng nhập hết hạn');
      }
      return;
    }

    final myRole = _resolvedRoleOrNull()!;
    final relationshipMode = _resolvedRelationshipModeOrNull()!;

    const defaultNameU1 = 'Bạn Nam';
    const defaultNameU2 = 'Bạn Nữ';
    final houseName = _houseNameCtrl.text.trim().isNotEmpty
        ? _houseNameCtrl.text.trim()
        : _defaultHouseName();
    final myDisplayName = myRole == 'user2' ? defaultNameU2 : defaultNameU1;

    final recoveryQuestion = _enableRecovery ? _selectedSecurityQuestion : '';
    if (_enableRecovery && _isBirthQuestion(recoveryQuestion)) {
      final validationError = DateInputUtils.validationError(
        _recoveryACtrl.text,
        firstYear: 1900,
        lastYear: DateTime.now().year,
        allowMissingYear: true,
      );
      if (validationError != null) {
        _showError(validationError);
        return;
      }
    }
    final recoveryAnswer = _enableRecovery
        ? (_isBirthQuestion(recoveryQuestion)
            ? DateInputUtils.canonicalRecoveryAnswer(_recoveryACtrl.text)
            : _recoveryACtrl.text.trim())
        : '';
    if (_enableRecovery &&
        (recoveryQuestion.isEmpty || recoveryAnswer.isEmpty)) {
      _showError(
        'Nếu bật câu hỏi bảo mật thì bạn cần nhập đủ câu hỏi và câu trả lời.',
      );
      return;
    }

    setState(() => _isLoading = true);
    debugPrint(
      '[HouseOnboarding] _createHouse start '
      '(autoCreateOnly: ${widget.autoCreateOnly}, role: $myRole, mode: $relationshipMode)',
    );
    var handedOffToParent = false;
    try {
      final existingHouseId =
          await _houseService.getCurrentHouseId(preferFresh: true);
      if (existingHouseId != null && existingHouseId.isNotEmpty) {
        debugPrint(
          '[HouseOnboarding] _createHouse found existing house: $existingHouseId',
        );
        final prefs = await OfflineCacheService.getPrefs();
        await prefs.setString('il_house_id', existingHouseId);
        await prefs.setString('il_auth_uid', user.uid);
        await SecureStorageService.instance
            .write(SecureStorageService.keyHouseId, existingHouseId);
        await SecureStorageService.instance
            .write(SecureStorageService.keyAuthUid, user.uid);
        if (widget.onHouseCreated != null) {
          await widget.onHouseCreated!.call();
          return;
        }
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AppEntry()),
            (route) => false,
          );
        }
        return;
      }

      final createdHouseId = await _houseService
          .createHouseForCurrentUser(
        email: user.email ?? '',
        houseName: houseName,
        nameU1: defaultNameU1,
        nameU2: defaultNameU2,
        relationshipMode: relationshipMode,
        recoveryQuestion: _enableRecovery ? recoveryQuestion : null,
        recoveryAnswer: _enableRecovery ? recoveryAnswer : null,
        createdWith: 'email',
        otp: houseCreationOtp,
        customHouseId: customHouseId,
      )
          .timeout(const Duration(seconds: 60), onTimeout: () {
        throw TimeoutException('_createHouse timed out');
      });
      debugPrint('[HouseOnboarding] _createHouse success: $createdHouseId');
      _authSyncRetryCount = 0;
      _transientCreateRetryCount = 0;
      if (!mounted) return;
      final resolvedHouseName = houseName;

      if (myRole != 'user1') {
        try {
          await FirebaseDatabase.instance
              .ref('houses/$createdHouseId/members/${user.uid}/role')
              .set(myRole);
        } catch (e) {
          debugPrint('[HouseOnboarding] Failed to sync role to db: $e');
        }
      }

      final prefs = await OfflineCacheService.getPrefs();
      await prefs.setString('il_user_name', myDisplayName);
      await prefs.setString('il_role', myRole);
      await prefs.setString('il_house_id', createdHouseId);
      await prefs.setString('il_auth_uid', user.uid);
      await prefs.setString('il_house_name', resolvedHouseName);
      await prefs.setString(
        'il_login_ts',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await prefs.setString('il_rel_mode', relationshipMode);
      await prefs.setString('il_new_user_welcome_v2', '1');
      await prefs.setString(
        'il_first_setup_guide_pending_v2_$createdHouseId',
        '1',
      );

      final email = (user.email ?? '').trim().toLowerCase();
      if (email.isNotEmpty) {
        await prefs.setString(
          _authService.relationshipModePrefsKey(email),
          relationshipMode,
        );
      }
      await _clearPendingSignupDraft(prefs: prefs);
      if (!mounted) return;

      if (widget.onHouseCreated != null) {
        // AppEntry may replace this screen immediately after this callback.
        // Avoid any further local setState in `finally` once control is handed
        // back to the parent flow.
        handedOffToParent = true;
        await widget.onHouseCreated!.call();
        return;
      }

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppEntry()),
        (route) => false,
      );
    } on HouseCreationOtpRequiredException catch (e) {
      debugPrint(
          '[HouseOnboarding] house creation OTP required: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Cần xác minh Gmail để tiếp tục tạo nhà.',
      ).message}');
      if (!mounted) return;
      final otp = await _promptHouseCreationOtp(e);
      if (!mounted) return;
      if (otp == null || otp.trim().isEmpty) {
        _setAutoCreateFailureMessage(
          'Cần nhập mã Gmail để tiếp tục tạo ngôi nhà này.',
          error: e,
        );
        return;
      }
      return _createHouse(
          houseCreationOtp: otp.trim(), customHouseId: customHouseId);
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(e);
      debugPrint('[HouseOnboarding] _createHouse failed: ${errorInfo.message}');
      if (!mounted) return;
      final message = errorInfo.message;

      final normalizedError = errorInfo.message.toLowerCase();
      final shouldRetryAuthSync = widget.autoCreateOnly &&
          _authSyncRetryCount < 4 &&
          (normalizedError.contains('unauthenticated') ||
              normalizedError.contains('chưa đăng nhập') ||
              message.toLowerCase().contains('đồng bộ'));
      if (shouldRetryAuthSync) {
        _authSyncRetryCount += 1;
        try {
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
        } catch (_) {}
        debugPrint(
          '[HouseOnboarding] Auth sync delay detected, retrying '
          '$_authSyncRetryCount/4...',
        );
        await Future.delayed(Duration(milliseconds: 700 * _authSyncRetryCount));
        if (mounted) {
          return _createHouse(
              houseCreationOtp: houseCreationOtp, customHouseId: customHouseId);
        }
      }
      _authSyncRetryCount = 0;

      final shouldRetryTransient = widget.autoCreateOnly &&
          _transientCreateRetryCount < 2 &&
          (e is TimeoutException ||
              normalizedError.contains('timeout') ||
              normalizedError.contains('timed out') ||
              normalizedError.contains('network') ||
              normalizedError.contains('unavailable') ||
              normalizedError.contains('deadline') ||
              normalizedError.contains('mạng') ||
              normalizedError.contains('kết nối'));
      if (shouldRetryTransient) {
        _transientCreateRetryCount += 1;
        debugPrint(
          '[HouseOnboarding] transient create failure, retrying '
          '$_transientCreateRetryCount/2...',
        );
        await Future.delayed(Duration(seconds: _transientCreateRetryCount));
        if (mounted) {
          return _createHouse(
              houseCreationOtp: houseCreationOtp, customHouseId: customHouseId);
        }
      }
      final isAlreadyExistsError = normalizedError.contains('đã có nhà') ||
          normalizedError.contains('đã tồn tại') ||
          normalizedError.contains('already exists') ||
          normalizedError.contains('already_exists') ||
          normalizedError.contains('tồn tại');
      if (isAlreadyExistsError) {
        try {
          final existingHouseId =
              await _houseService.getCurrentHouseId(preferFresh: true);
          if (existingHouseId != null && existingHouseId.isNotEmpty) {
            debugPrint(
              '[HouseOnboarding] Existing house recovered after creation collision: $existingHouseId',
            );
            _authSyncRetryCount = 0;
            _transientCreateRetryCount = 0;
            if (!mounted) return;
            if (widget.onHouseCreated != null) {
              handedOffToParent = true;
              await widget.onHouseCreated!.call();
              return;
            }
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AppEntry()),
              (route) => false,
            );
            return;
          }
        } catch (recoverErr) {
          debugPrint(
            '[HouseOnboarding] Failed to recover existing house: $recoverErr',
          );
        }
      }

      if (widget.autoCreateOnly) {
        _setAutoCreateFailureMessage(message, error: e);
      } else {
        _showError(message);
      }
    } finally {
      if (mounted && !handedOffToParent) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _resolveErrorTitle(String message) {
    final normalized = message.trim().toLowerCase();
    if (normalized.contains('giới hạn') ||
        normalized.contains('quá nhiều') ||
        normalized.contains('thử lại sau khoảng')) {
      return 'Đã đạt giới hạn';
    }
    if (normalized.contains('app check') ||
        normalized.contains('debug token') ||
        normalized.contains('play integrity')) {
      return 'Cấu hình bản debug chưa đủ';
    }
    if (normalized.contains('đăng xuất')) {
      return 'Không thể đăng xuất';
    }
    if (normalized.contains('bảo mật') ||
        normalized.contains('câu hỏi') ||
        normalized.contains('câu trả lời')) {
      return 'Thiếu thông tin';
    }
    return 'Không thể tạo nhà';
  }

  void _showError(String message, {String? title}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        title: Text(
          title ?? _resolveErrorTitle(message),
          style: SLTheme.quicksand(
            color: const Color(0xFFD81B60),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          message,
          style: SLTheme.quicksand(height: 1.4, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              L10nService().translate('Đóng'),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD81B60),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showCustomIdScreen) {
      return Scaffold(
        backgroundColor: const Color(0xFFFDF7FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (widget.onSignedOut != null)
              TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          await FirebaseAuth.instance.signOut();
                          if (widget.onSignedOut != null) {
                            await widget.onSignedOut!();
                          }
                        } catch (_) {}
                        if (mounted) setState(() => _isLoading = false);
                      },
                icon: const Icon(Icons.logout_rounded,
                    color: Color(0xFFD81B60), size: 20),
                label: Text(
                  'Đăng xuất',
                  style: SLTheme.quicksand(
                    color: const Color(0xFFD81B60),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            // --- Premium Ambient Blobs ---
            Positioned.fill(
              child: RepaintBoundary(
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeInOutSine,
                      top: -100,
                      left: -150,
                      child: Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFF6FA3).withValues(alpha: 0.45),
                              const Color(0xFFFF6FA3).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 1400),
                      curve: Curves.easeInOutSine,
                      bottom: -150,
                      right: -200,
                      child: Container(
                        width: 600,
                        height: 600,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF9030C0).withValues(alpha: 0.35),
                              const Color(0xFF9030C0).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: FastBackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                        fallbackColor: Colors.white.withValues(alpha: 0.6),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: FastBackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      fallbackColor: Colors.white.withValues(alpha: 0.85),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6A1B9A)
                                  .withValues(alpha: 0.08),
                              blurRadius: 40,
                              spreadRadius: 8,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              size: 52,
                              color: Color(0xFFD81B60),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tạo Tổ Ấm Của Hai Bạn',
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2C1B22),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Thiết lập một Mã Nhà (ID) duy nhất để đối phương có thể kết nối với bạn nhé.',
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 14,
                                height: 1.45,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7A6871),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF6FA),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _idErrorReason != null
                                      ? Colors.red.shade200
                                      : (_isIdAvailable
                                          ? Colors.green.shade200
                                          : const Color(0xFFFFD3E4)),
                                ),
                              ),
                              child: TextField(
                                controller: _customIdCtrl,
                                maxLength: 20,
                                autofocus: true,
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF2C1B22),
                                ),
                                decoration: InputDecoration(
                                  labelText:
                                      'Mã nhà của bạn (Ví dụ: NHATHUONG_99)',
                                  labelStyle: SLTheme.quicksand(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF8C7381),
                                  ),
                                  counterText: '',
                                  border: InputBorder.none,
                                  suffixIcon: _isIdChecking
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Center(
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Color(0xFFD81B60),
                                              ),
                                            ),
                                          ),
                                        )
                                      : (_isIdAvailable
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.green)
                                          : (_idErrorReason != null
                                              ? const Icon(Icons.cancel_rounded,
                                                  color: Colors.red)
                                              : null)),
                                ),
                                onChanged: _onIdChanged,
                              ),
                            ),
                            if (_isIdAvailable) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded,
                                      color: Colors.green, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Mã nhà khả dụng và hợp lệ!',
                                      style: SLTheme.quicksand(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_idErrorReason != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Colors.red, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _idErrorReason!,
                                      style: SLTheme.quicksand(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_idSuggestions.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Gợi ý mã nhà chưa tồn tại cho bạn:',
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF7A6871),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _idSuggestions.map((sugg) {
                                  return ActionChip(
                                    label: Text(
                                      sugg,
                                      style: SLTheme.quicksand(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFD81B60),
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFFFF0F5),
                                    side: const BorderSide(
                                        color: Color(0xFFFFD3E4)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    onPressed: () => _selectSuggestion(sugg),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 28),
                            ElevatedButton(
                              onPressed: (_isIdAvailable &&
                                      !_isLoading &&
                                      !_isIdChecking)
                                  ? () => _createHouse(customHouseId: _customId)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD81B60),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFFF3E5EB),
                                disabledForegroundColor:
                                    const Color(0xFFC3AEB9),
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Thiết lập & Tạo nhà',
                                      style: SLTheme.quicksand(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.autoCreateOnly) {
      if (_autoCreateFailureMessage == null) {
        return const LoadingScaffold();
      }

      return Scaffold(
        backgroundColor: const Color(0xFFFDF7FA),
        body: Stack(
          children: [
            // --- Premium Ambient Blobs ---
            Positioned.fill(
              child: RepaintBoundary(
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeInOutSine,
                      top: -100,
                      left: -150,
                      child: Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFF6FA3).withValues(alpha: 0.45),
                              const Color(0xFFFF6FA3).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 1400),
                      curve: Curves.easeInOutSine,
                      bottom: -150,
                      right: -200,
                      child: Container(
                        width: 600,
                        height: 600,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF9030C0).withValues(alpha: 0.35),
                              const Color(0xFF9030C0).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: FastBackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                        fallbackColor: Colors.white.withValues(alpha: 0.6),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: FastBackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        fallbackColor: Colors.white.withValues(alpha: 0.85),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6A1B9A)
                                    .withValues(alpha: 0.08),
                                blurRadius: 40,
                                spreadRadius: 8,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Icon(
                                Icons.home_work_rounded,
                                size: 42,
                                color: Color(0xFFD81B60),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Không thể chuẩn bị ngôi nhà',
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFD81B60),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _autoCreateFailureMessage ??
                                    'Đã có lỗi xảy ra khi chuẩn bị ngôi nhà. Vui lòng thử lại.',
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  height: 1.45,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6D5C63),
                                ),
                              ),
                              if (kDebugMode &&
                                  _autoCreateFailureDetail != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1F5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Chi tiết: $_autoCreateFailureDetail',
                                    textAlign: TextAlign.center,
                                    style: SLTheme.quicksand(
                                      height: 1.35,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF9F1239),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        _authSyncRetryCount = 0;
                                        _transientCreateRetryCount = 0;
                                        _createHouse();
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD81B60),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  'Thử lại',
                                  style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (_needsEmailVerification(
                                null,
                                _autoCreateFailureMessage ?? '',
                              )) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _sendGmailVerification,
                                  icon:
                                      const Icon(Icons.mark_email_read_rounded),
                                  label: Text(
                                    'Xác minh Gmail',
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFD81B60),
                                    side: const BorderSide(
                                        color: Color(0xFFD81B60)),
                                    minimumSize: const Size.fromHeight(50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const LoadingScaffold();
  }

  Widget _buildScrollHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: SLRadius.pillAll,
          border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vuốt xuống để xem tiếp',
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF91536F),
              ),
            ),
            SLSpacing.w8,
            const Icon(
              Icons.keyboard_double_arrow_down_rounded,
              color: Color(0xFFD81B60),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackdropBubble({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: SLRadius.pillAll,
        border: Border.all(color: const Color(0x18D81B60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFD81B60)),
          SLSpacing.w8,
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF7A5566),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCallout({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: SLSpacing.all12,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6F9), Color(0xFFFFEEF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22D81B60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFD81B60),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF8A1E46),
                  ),
                ),
                SLSpacing.h4,
                Text(
                  body,
                  style: SLTheme.quicksand(
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6D5C63),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: const Color(0x14D81B60)),
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
                  color: const Color(0xFFFFEEF4),
                  borderRadius: SLRadius.mdAll,
                ),
                child: Icon(icon, color: const Color(0xFFD81B60)),
              ),
              SLSpacing.w8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF8A1E46),
                      ),
                    ),
                    SLSpacing.gapH(2),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A6A72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          child,
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String description,
    required String value,
    required Color color,
  }) {
    final selected = _mode == value;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _mode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: SLSpacing.all12,
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
            width: 1.6,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.18)
                    : color.withValues(alpha: 0.12),
                borderRadius: SLRadius.mdAll,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : color,
              ),
            ),
            SLSpacing.h8,
            Text(
              title,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: selected ? Colors.white : color,
              ),
            ),
            SLSpacing.h8,
            Text(
              description,
              style: SLTheme.quicksand(
                height: 1.4,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white.withValues(alpha: 0.92)
                    : const Color(0xFF6E6067),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? helper,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        SLSpacing.h8,
        TextField(
          controller: controller,
          maxLength: maxLength,
          style: SLTheme.quicksand(fontWeight: FontWeight.w700),
          decoration: _inputDecoration(
            hint: hint,
            prefixIcon: Icons.home_rounded,
          ),
        ),
        if (helper != null) ...[
          SLSpacing.h8,
          Text(
            helper,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF887880),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuestionAvatarPlaceholder() {
    return Container(
      color: const Color(0xFFD1D5DB),
      alignment: Alignment.center,
      child: Text(
        '?',
        style: SLTheme.quicksand(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: SLTheme.quicksand(
        fontSize: 13,
        color: const Color(0xFF6D5F67),
        fontWeight: FontWeight.w900,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    String? helper,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      helperText: helper,
      hintStyle: SLTheme.quicksand(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: const Color(0xFFD81B60), size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: SLRadius.lgAll,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: SLRadius.lgAll,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: SLRadius.lgAll,
        borderSide: const BorderSide(color: Color(0xFFD81B60), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
