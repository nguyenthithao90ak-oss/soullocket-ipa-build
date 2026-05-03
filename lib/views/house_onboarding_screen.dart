// ignore_for_file: dead_code, unnecessary_null_comparison

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/l10n_service.dart';
import '../services/auth_service.dart';
import '../services/house_service.dart';
import '../utils/app_error_mapper.dart';
import '../utils/flexible_date_input.dart';
import 'app_entry.dart';
import 'app_entry/widgets/loading_scaffold.dart';
import 'auth/widgets/gender_selection_dialog.dart';
import 'auth/widgets/relationship_mode_dialog.dart';
import 'login_screen.dart';
import '../core/sl_theme.dart';

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
  static const String _defaultHouseName = 'Chúng mình';
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
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  String _mode = 'couple';
  bool _hasResolvedRelationshipMode = false;
  String? _cachedRole;
  bool _enableRecovery = false;
  bool _showScrollHint = false;
  bool _dismissedScrollHint = false;
  bool _didQueueAutoCreate = false;
  bool _isPromptingCreationSetup = false;
  final bool _showLegacyIntro = false;
  Timer? _scrollHintTimer;
  String? _autoCreateFailureMessage;
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
      _houseNameCtrl.text = _defaultHouseName;
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

    if (!widget.autoCreateOnly && !shouldAutoCreate) return;
    if (_didQueueAutoCreate) return;

    var missingSetupMessage = _creationPrerequisiteErrorMessage();
    if (missingSetupMessage != null) {
      await _promptForMissingCreationPrerequisites(prefs: prefs);
      if (!mounted) return;
      missingSetupMessage = _creationPrerequisiteErrorMessage();
    }
    if (missingSetupMessage != null) {
      _didQueueAutoCreate = true;
      if (shouldAutoCreate) {
        await prefs.remove(_pendingSignupAutoCreateHousePrefsKey);
      }
      _setAutoCreateFailureMessage(missingSetupMessage);
      return;
    }

    if (_houseNameCtrl.text.trim().isEmpty) {
      _houseNameCtrl.text = _defaultHouseName;
    }

    _didQueueAutoCreate = true;
    if (shouldAutoCreate) {
      await prefs.remove(_pendingSignupAutoCreateHousePrefsKey);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoading) return;
      debugPrint('[HouseOnboarding] autoCreateOnly -> _createHouse queued');
      _createHouse();
    });
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
    super.dispose();
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
                onSelected: (mode) => Navigator.of(dialogContext).pop(mode),
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
                onSelected: (role) => Navigator.of(dialogContext).pop(role),
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
      return 'Thiếu lựa chọn Độc thân/Có người yêu và vai trò tài khoản. Hãy chọn để tiếp tục tạo nhà.';
    }
    if (relationshipMode == null) {
      return 'Thiếu lựa chọn Độc thân/Có người yêu. Hãy chọn để tiếp tục tạo nhà.';
    }
    return 'Thiếu vai trò tài khoản. Hãy chọn để tiếp tục tạo nhà.';

    if (relationshipMode != null && role != null) {
      return null;
    }
    if (relationshipMode == null && role == null) {
      return 'Thiếu lựa chọn Độc thân/Có người yêu và vai trò tài khoản. Vui lòng đăng xuất rồi đăng nhập lại để chọn đúng trước khi tạo nhà.';
    }
    if (relationshipMode == null) {
      return 'Thiếu lựa chọn Độc thân/Có người yêu. Vui lòng đăng xuất rồi đăng nhập lại để chọn đúng trước khi tạo nhà.';
    }
    return 'Thiếu vai trò tài khoản. Vui lòng đăng xuất rồi đăng nhập lại để chọn đúng trước khi tạo nhà.';
  }

  void _setAutoCreateFailureMessage(String message) {
    if (!mounted || _autoCreateFailureMessage == message) return;
    setState(() => _autoCreateFailureMessage = message);
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
        setState(() {
          _autoCreateFailureMessage = AppErrorMapper.resolve(
            e,
            fallbackMessage:
                'Không tạo được ngôi nhà: hãy kiểm tra trạng thái đăng nhập và kết nối mạng.',
          ).message;
        });
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

  Future<void> _createHouse() async {
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
        : _defaultHouseName;
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
      )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('_createHouse timed out');
      });
      debugPrint('[HouseOnboarding] _createHouse success: $createdHouseId');
      _authSyncRetryCount = 0;
      _transientCreateRetryCount = 0;
      if (!mounted) return;
      final resolvedHouseName = houseName;

      final prefs = await SharedPreferences.getInstance();
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
      await prefs.setString('il_new_user_pro_trial_notice', '1');
      await prefs.setString(
        'il_first_setup_guide_pending_$createdHouseId',
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
    } catch (e, st) {
      debugPrint('[HouseOnboarding] _createHouse failed: $e\n$st');
      if (!mounted) return;
      final errorInfo = AppErrorMapper.resolve(e);
      final message = errorInfo.message;

      if (errorInfo.isUserError &&
          _authSyncRetryCount < 1 &&
          (e.toString().contains('Unauthenticated') ||
              e.toString().contains('Bạn chưa đăng nhập'))) {
        _authSyncRetryCount += 1;
        debugPrint('[HouseOnboarding] Auth sync delay detected, retrying in 1s...');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          return _createHouse();
        }
      }
      _authSyncRetryCount = 0;

      final normalizedError = e.toString().toLowerCase();
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
          '${_transientCreateRetryCount}/2...',
        );
        await Future.delayed(Duration(seconds: _transientCreateRetryCount));
        if (mounted) {
          return _createHouse();
        }
      }
      _transientCreateRetryCount = 0;

      if (widget.autoCreateOnly) {
        _setAutoCreateFailureMessage(message);
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
    if (widget.autoCreateOnly) {
      if (_autoCreateFailureMessage == null) {
        return const LoadingScaffold();
      }

      return Scaffold(
        backgroundColor: const Color(0xFFFFF7FB),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 28,
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
                        _autoCreateFailureMessage ?? 'Đã có lỗi xảy ra khi chuẩn bị ngôi nhà. Vui lòng thử lại.',
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6D5C63),
                        ),
                      ),
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
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _isLoading ? null : _signOutToLogin,
                        child: Text(
                          'Đăng xuất',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD81B60),
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
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFB2C7),
                  Color(0xFFFFE3EB),
                  Color(0xFFD6C2FF),
                  Color(0xFFFDE7F5),
                ],
              ),
            ),
          ),
          Positioned(
            top: -70,
            left: -30,
            child: _buildBackdropBubble(
              size: 180,
              color: Colors.white.withOpacity(0.24),
            ),
          ),
          Positioned(
            top: 110,
            right: -35,
            child: _buildBackdropBubble(
              size: 140,
              color: const Color(0xFFD81B60).withOpacity(0.12),
            ),
          ),
          Positioned(
            bottom: -40,
            left: 10,
            child: _buildBackdropBubble(
              size: 160,
              color: const Color(0xFFA18CD1).withOpacity(0.14),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 88),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.7)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 34,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showLegacyIntro) ...[
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6E9F), Color(0xFFD81B60)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFD81B60).withOpacity(0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.cottage_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                          SLSpacing.h12,
                          Text(
                            'TẠO NGÔI NHÀ MỚI',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFD81B60),
                            ),
                          ),
                          SLSpacing.h8,
                          Text(
                            'Hoàn tất bước cuối để bắt đầu hành trình trong SoulLocket. Email và mật khẩu đã được thiết lập ở bước trước rồi.',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6D5C63),
                            ),
                          ),
                          SLSpacing.h12,
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildHeroChip(Icons.flag_rounded, 'Bước 2 / 2'),
                              _buildHeroChip(
                                Icons.favorite_rounded,
                                'Giao diện hiện đại',
                              ),
                              _buildHeroChip(
                                Icons.settings_suggest_rounded,
                                'Có thể đổi lại sau',
                              ),
                            ],
                          ),
                          SLSpacing.h16,
                          _buildInfoCallout(
                            icon: Icons.info_rounded,
                            title: 'Bạn đang thiết lập gì ở bước này?',
                            body:
                                'Đặt tên cho ngôi nhà và thêm thông tin khôi phục nếu muốn an toàn hơn khi quên dữ liệu đăng nhập.',
                          ),
                          SLSpacing.h16,
                        ],
                        _buildSectionCard(
                          title: 'Thông tin ngôi nhà',
                          subtitle:
                              'Tên này sẽ hiện ở Trang chủ, phần cài đặt và các màn chia sẻ sau này.',
                          icon: Icons.home_work_rounded,
                          child: _buildField(
                            label: 'Tên ngôi nhà (Không bắt buộc)',
                            controller: _houseNameCtrl,
                            hint: 'Ví dụ: Nhà của chúng mình',
                            maxLength: 30,
                            helper:
                                'Nếu để trống, app sẽ dùng mã nhà làm tên nhà mặc định.',
                          ),
                        ),
                        SLSpacing.h12,
                        _buildInfoCallout(
                          icon: Icons.groups_rounded,
                          title: 'Tên mặc định đã được gắn sẵn',
                          body:
                              'Sau khi tạo, app sẽ dùng sẵn hai tên "Bạn Nam" và "Bạn Nữ". Bạn có thể đổi lại trong Cài đặt bất cứ lúc nào.',
                        ),
                        SLSpacing.h12,
                        _buildSectionCard(
                          title: 'Khôi phục bảo mật',
                          subtitle:
                              'Tùy chọn này giúp lấy lại quyền truy cập dễ hơn nếu sau này quên thông tin nhà.',
                          icon: Icons.lock_reset_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: SLSpacing.all12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3F7),
                                  borderRadius: SLRadius.lgAll,
                                  border: Border.all(
                                      color: const Color(0x22D81B60)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Bật câu hỏi bảo mật',
                                            style: SLTheme.quicksand(
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFFD81B60),
                                            ),
                                          ),
                                          SLSpacing.h4,
                                          Text(
                                            'Nếu bật, bạn nên chọn câu hỏi thật dễ nhớ nhưng khó đoán với người lạ.',
                                            style: SLTheme.quicksand(
                                              height: 1.4,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF7B5A67),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SLSpacing.w8,
                                    Switch(
                                      value: _enableRecovery,
                                      onChanged: (value) => setState(
                                          () => _enableRecovery = value),
                                      activeColor: const Color(0xFFD81B60),
                                    ),
                                  ],
                                ),
                              ),
                              if (_enableRecovery) ...[
                                SLSpacing.h12,
                                _buildLabel('Câu hỏi bảo mật'),
                                SLSpacing.h8,
                                DropdownButtonFormField<String>(
                                  value: _selectedSecurityQuestion,
                                  isExpanded: true,
                                  style: SLTheme.quicksand(
                                    color: const Color(0xFF58455B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: _inputDecoration(
                                    hint: 'Chọn câu hỏi bảo mật',
                                  ),
                                  items: _securityQuestions
                                      .map(
                                        (question) => DropdownMenuItem(
                                          value: question,
                                          child: Text(
                                            question,
                                            overflow: TextOverflow.ellipsis,
                                            style: SLTheme.quicksand(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _selectedSecurityQuestion = value;
                                      _recoveryACtrl.clear();
                                    });
                                  },
                                ),
                                SLSpacing.h12,
                                _buildLabel('Câu trả lời'),
                                SLSpacing.h8,
                                _selectedSecurityQuestion ==
                                        L10nService()
                                            .translate('Ngày sinh của bạn?')
                                    ? GestureDetector(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate:
                                                DateTime.now().subtract(
                                              const Duration(days: 365 * 18),
                                            ),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                            builder: (context, child) => Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme:
                                                    const ColorScheme.light(
                                                  primary: Color(0xFFD81B60),
                                                ),
                                              ),
                                              child: child!,
                                            ),
                                          );
                                          if (picked == null) return;
                                          setState(() {
                                            _recoveryACtrl.text = DateInputUtils
                                                .formatDisplayDate(picked);
                                          });
                                        },
                                        child: AbsorbPointer(
                                          absorbing: false,
                                          child: TextField(
                                            controller: _recoveryACtrl,
                                            keyboardType:
                                                TextInputType.datetime,
                                            inputFormatters: const [
                                              FlexibleDateInputFormatter()
                                            ],
                                            textInputAction:
                                                TextInputAction.done,
                                            onEditingComplete:
                                                _normalizeRecoveryBirthAnswer,
                                            onSubmitted: (_) =>
                                                _normalizeRecoveryBirthAnswer(),
                                            style: SLTheme.quicksand(
                                              fontWeight: FontWeight.w700,
                                            ),
                                            decoration: _inputDecoration(
                                              hint: 'ngày/tháng/năm',
                                              helper:
                                                  'Đang nhập ngày/tháng/năm',
                                              prefixIcon:
                                                  Icons.calendar_month_rounded,
                                            ),
                                          ),
                                        ),
                                      )
                                    : TextField(
                                        controller: _recoveryACtrl,
                                        style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: _inputDecoration(
                                          hint: 'Nhập câu trả lời',
                                          prefixIcon: Icons.key_rounded,
                                        ),
                                      ),
                              ],
                            ],
                          ),
                        ),
                        SLSpacing.h16,
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createHouse,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD81B60),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: SLRadius.lgAll,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.6,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'TẠO NHÀ NGAY',
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                        SLSpacing.h8,
                        Text(
                          'Tạo xong sẽ vào thẳng trong app. Nếu chưa đặt tên nhà, mã nhà sẽ được dùng làm tên mặc định.',
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7B6A72),
                          ),
                        ),
                        SLSpacing.h8,
                        TextButton.icon(
                          onPressed: _isLoading ? null : _signOutToLogin,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: Text(
                            'Đăng xuất và dùng tài khoản khác',
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD81B60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                opacity: _showScrollHint ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  offset: _showScrollHint ? Offset.zero : const Offset(0, 0.25),
                  child: _buildScrollHint(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: SLRadius.pillAll,
          border: Border.all(color: Colors.white.withOpacity(0.92)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
        color: Colors.white.withOpacity(0.82),
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
        color: Colors.white.withOpacity(0.8),
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

  // ignore: unused_element
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
            color: selected ? color : color.withOpacity(0.35),
            width: 1.6,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.24),
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
                    ? Colors.white.withOpacity(0.18)
                    : color.withOpacity(0.12),
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
                    ? Colors.white.withOpacity(0.92)
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

  // ignore: unused_element
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
