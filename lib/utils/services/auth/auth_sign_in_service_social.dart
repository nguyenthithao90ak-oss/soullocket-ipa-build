part of 'auth_sign_in_service.dart';

extension AuthSignInServiceSocial on AuthSignInService {
  Future<bool> _isProviderLinkedCurrentUser(String providerId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final generation = AuthSignInService._signOutGenerations[_auth] ?? 0;
    _requireAuthSession(generation, uid: user.uid);

    try {
      await user.reload();
    } catch (error) {
      debugPrint('[AuthSocial] Không tải lại được provider hiện tại: $error');
    }

    _requireAuthSession(generation, uid: user.uid);
    final providerData = _auth.currentUser!.providerData;
    return providerData.any((provider) => provider.providerId == providerId);
  }

  Future<bool> isGoogleLinkedCurrentUser() {
    return _isProviderLinkedCurrentUser('google.com');
  }

  String? getGoogleLinkedEmail() {
    final user = _auth.currentUser;
    if (user == null) return null;
    final providerData = user.providerData;
    for (final provider in providerData) {
      if (provider.providerId == 'google.com') {
        return provider.email;
      }
    }
    return null;
  }

  Future<bool> isAppleLinkedCurrentUser() {
    return _isProviderLinkedCurrentUser('apple.com');
  }

  Future<bool> isPasswordLinkedCurrentUser() {
    return _isProviderLinkedCurrentUser('password');
  }

  Future<void> linkGoogleToCurrentUser() =>
      _runAuthOperation(_linkGoogleToCurrentUser);

  Future<void> _linkGoogleToCurrentUser(int generation) async {
    var user = _auth.currentUser;
    if (user == null) {
      throw UiCopy.text('copy_ba3ce6b45be4');
    }

    _requireAuthSession(generation, uid: user.uid);
    final linked = await isGoogleLinkedCurrentUser();
    _requireAuthSession(generation, uid: user.uid);
    if (linked) return;

    final provider = firebase_auth.GoogleAuthProvider()..addScope('email');
    provider.setCustomParameters({'prompt': 'select_account'});

    try {
      if (kIsWeb) {
        await _runNativeAuthRequest(
          () => user!.linkWithPopup(provider),
          signOutGeneration: generation,
        );
      } else {
        final googleUser = await _selectGoogleAccount(
          generation,
          uid: user.uid,
        );
        final googleAuth = googleUser.authentication;
        if ((googleAuth.idToken ?? '').isEmpty) {
          throw UiCopy.text('copy_f82aa856e91f');
        }

        final credential = firebase_auth.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await _runNativeAuthRequest(
          () => user!.linkWithCredential(credential),
          signOutGeneration: generation,
        );
      }

      _requireAuthSession(generation, uid: user.uid);
      await user.reload();
      _requireAuthSession(generation, uid: user.uid);
      user = _auth.currentUser!;
      await _houseContextService.syncSecurityEmailForCurrentUser(user: user);
      _requireAuthSession(generation, uid: user.uid);
    } on firebase_auth.FirebaseAuthException catch (error) {
      _requireAuthSession(generation, uid: user!.uid);
      switch (error.code) {
        case 'provider-already-linked':
          return;
        case 'credential-already-in-use':
        case 'email-already-in-use':
        case 'account-exists-with-different-credential':
          throw UiCopy.text('copy_08d7dd1facf5');
        case 'requires-recent-login':
          throw UiCopy.text('copy_1c54ebfdd9df');
        case 'popup-closed-by-user':
          throw UiCopy.text('copy_21749000c8a0');
        case 'popup-blocked':
        case 'cancelled-popup-request':
          throw UiCopy.text('copy_4c6335e28066');
        case 'network-request-failed':
          throw UiCopy.text('copy_3f3929986e93');
        default:
          throw handleFirebaseAuthError(error);
      }
    } catch (error) {
      final errStr = error.toString().toLowerCase();
      bool isRealCancel = true;
      if (error is PlatformException && error.code == 'sign_in_failed') {
        isRealCancel = false;
      }
      if (isRealCancel &&
          (errStr.contains('sign_in_canceled') ||
              errStr.contains('canceled') ||
              errStr.contains('cancelled'))) {
        throw UiCopy.text('copy_4cccee9577ae');
      }
      if (isGoogleSignInConfigMismatch(error)) {
        throw UiCopy.text('copy_d3bda4768414');
      }
      if (isGoogleSignInNetworkIssue(error)) {
        throw UiCopy.text('copy_3f3929986e93');
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate('auth_fallback_google_link'),
      ).message;
    }
  }

  Future<void> linkAppleToCurrentUser() =>
      _runAuthOperation(_linkAppleToCurrentUser);

  Future<void> _linkAppleToCurrentUser(int generation) async {
    var user = _auth.currentUser;
    if (user == null) {
      throw UiCopy.text('copy_cb88670faeb1');
    }

    _requireAuthSession(generation, uid: user.uid);
    final linked = await isAppleLinkedCurrentUser();
    _requireAuthSession(generation, uid: user.uid);
    if (linked) return;

    try {
      if (kIsWeb) {
        final provider = firebase_auth.AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        await _runNativeAuthRequest(
          () => user!.linkWithPopup(provider),
          signOutGeneration: generation,
        );
      } else if (!_usesNativeAppleFlow) {
        final provider = firebase_auth.AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        await _runNativeAuthRequest(
          () => user!.linkWithProvider(provider),
          signOutGeneration: generation,
        );
      } else {
        final oauthCredential = await _requestNativeAppleCredential(
          generation,
          uid: user.uid,
        );
        await _runNativeAuthRequest(
          () => user!.linkWithCredential(oauthCredential),
          signOutGeneration: generation,
        );
      }

      _requireAuthSession(generation, uid: user.uid);
      await user.reload();
      _requireAuthSession(generation, uid: user.uid);
      user = _auth.currentUser!;
      await _houseContextService.syncSecurityEmailForCurrentUser(user: user);
      _requireAuthSession(generation, uid: user.uid);
    } on firebase_auth.FirebaseAuthException catch (error) {
      _requireAuthSession(generation, uid: user!.uid);
      switch (error.code) {
        case 'provider-already-linked':
          return;
        case 'credential-already-in-use':
        case 'email-already-in-use':
        case 'account-exists-with-different-credential':
          throw UiCopy.text('copy_9a315310c935');
        case 'requires-recent-login':
          throw UiCopy.text('copy_83503900874c');
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
        case 'web-context-cancelled':
          return;
        case 'popup-blocked':
          throw UiCopy.text('copy_99a56919b762');
        case 'operation-not-allowed':
          throw kDebugMode
              ? UiCopy.text('copy_85202bcdedf7')
              : UiCopy.text('copy_82ae68ad2982');
        case 'network-request-failed':
          throw UiCopy.text('copy_e7fa1658c1aa');
        default:
          throw handleFirebaseAuthError(error);
      }
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return;
      }
      throw kDebugMode
          ? UiCopy.text('copy_94cb73e5c857', {'value1': error.code})
          : UiCopy.text('copy_6ea982614770');
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate('auth_fallback_apple_link'),
      ).message;
    }
  }

  Future<void> createPasswordForCurrentUser(String newPassword) =>
      _runAuthOperation(
        (generation) => _createPasswordForCurrentUser(newPassword, generation),
      );

  Future<void> _createPasswordForCurrentUser(
    String newPassword,
    int generation,
  ) async {
    var user = _auth.currentUser;
    if (user == null) {
      throw UiCopy.text('copy_27d42e4975c0');
    }

    final email = user.email?.trim() ?? '';
    final normalizedPassword = newPassword.trim();
    if (email.isEmpty) {
      throw UiCopy.text('copy_4202a22da8cd');
    }
    if (normalizedPassword.length < 6) {
      throw UiCopy.text('copy_4a11931017d1');
    }
    _requireAuthSession(generation, uid: user.uid);
    if (await isPasswordLinkedCurrentUser()) {
      throw UiCopy.text('copy_5a8d7b0b0484');
    }
    _requireAuthSession(generation, uid: user.uid);

    Future<void> linkPasswordCredential() async {
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: normalizedPassword,
      );
      _requireAuthSession(generation, uid: user!.uid);
      await _runNativeAuthRequest(
        () => user!.linkWithCredential(credential),
        signOutGeneration: generation,
      );
      _requireAuthSession(generation, uid: user.uid);
    }

    try {
      await linkPasswordCredential();
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        await _reauthenticateCurrentUserWithLinkedProvider(user, generation);
        _requireAuthSession(generation, uid: user.uid);
        user = _auth.currentUser!;
        await linkPasswordCredential();
      } else if (error.code == 'provider-already-linked') {
        await user.reload();
      } else if (error.code == 'email-already-in-use' ||
          error.code == 'credential-already-in-use' ||
          error.code == 'account-exists-with-different-credential') {
        throw UiCopy.text('copy_f5efcaa5e1b5');
      } else {
        throw handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate(
          'auth_fallback_password_create',
        ),
      ).message;
    }

    _requireAuthSession(generation, uid: user.uid);
    await user.reload();
    _requireAuthSession(generation, uid: user.uid);
    user = _auth.currentUser!;
    try {
      await _houseContextService.syncSecurityEmailForCurrentUser(user: user);
    } catch (error) {
      debugPrint('[AuthSocial] Không đồng bộ được email bảo mật: $error');
    }
  }

  Future<void> _reauthenticateCurrentUserWithLinkedProvider(
    firebase_auth.User user, [
    int? generation,
  ]) async {
    if (generation == null) {
      await _runAuthOperation(
        (current) =>
            _reauthenticateCurrentUserWithLinkedProvider(user, current),
      );
      return;
    }
    _requireAuthSession(generation, uid: user.uid);
    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .toSet();
    if (providerIds.contains('google.com')) {
      await _reauthenticateCurrentUserWithGoogle(user, generation);
      return;
    }
    if (providerIds.contains('apple.com')) {
      await _reauthenticateCurrentUserWithApple(user, generation);
      return;
    }
    if (providerIds.contains('facebook.com')) {
      throw UiCopy.text('copy_759b8bdbf042');
    }
    throw UiCopy.text('copy_647e89e2e05d');
  }

  Future<void> _reauthenticateCurrentUserWithGoogle(
    firebase_auth.User user,
    int generation,
  ) async {
    try {
      if (kIsWeb) {
        final provider = firebase_auth.GoogleAuthProvider()..addScope('email');
        provider.setCustomParameters({'prompt': 'select_account'});
        await _runNativeAuthRequest(
          () => user.reauthenticateWithPopup(provider),
          signOutGeneration: generation,
        );
        _requireAuthSession(generation, uid: user.uid);
        return;
      }

      final googleUser = await _selectGoogleAccount(generation, uid: user.uid);
      final googleAuth = googleUser.authentication;
      if ((googleAuth.idToken ?? '').isEmpty) {
        throw UiCopy.text('copy_8802343cdb61');
      }

      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await _runNativeAuthRequest(
        () => user.reauthenticateWithCredential(credential),
        signOutGeneration: generation,
      );
      _requireAuthSession(generation, uid: user.uid);
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'user-mismatch':
          throw UiCopy.text('copy_59b962780d3d');
        case 'popup-closed-by-user':
          throw UiCopy.text('copy_51a950751f0d');
        case 'popup-blocked':
        case 'cancelled-popup-request':
          throw UiCopy.text('copy_4c6335e28066');
        case 'network-request-failed':
          throw UiCopy.text('copy_8d11b55cdb38');
        default:
          throw handleFirebaseAuthError(error);
      }
    } catch (error) {
      final errStr = error.toString().toLowerCase();
      bool isRealCancel = true;
      if (error is PlatformException && error.code == 'sign_in_failed') {
        isRealCancel = false;
      }
      if (isRealCancel &&
          (errStr.contains('sign_in_canceled') ||
              errStr.contains('canceled') ||
              errStr.contains('cancelled'))) {
        throw UiCopy.text('copy_4cccee9577ae');
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate(
          'auth_fallback_google_reauthenticate',
        ),
      ).message;
    }
  }

  Future<void> _reauthenticateCurrentUserWithApple(
    firebase_auth.User user,
    int generation,
  ) async {
    _requireAuthSession(generation, uid: user.uid);
    if (kIsWeb) {
      await _runNativeAuthRequest(
        () => user.reauthenticateWithPopup(firebase_auth.AppleAuthProvider()),
        signOutGeneration: generation,
      );
    } else if (!_usesNativeAppleFlow) {
      await _runNativeAuthRequest(
        () =>
            user.reauthenticateWithProvider(firebase_auth.AppleAuthProvider()),
        signOutGeneration: generation,
      );
    } else {
      final credential = await _requestNativeAppleCredential(
        generation,
        uid: user.uid,
      );
      await _runNativeAuthRequest(
        () => user.reauthenticateWithCredential(credential),
        signOutGeneration: generation,
      );
    }
    _requireAuthSession(generation, uid: user.uid);
  }
}
