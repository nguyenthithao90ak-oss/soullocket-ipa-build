part of 'auth_sign_in_service.dart';

extension AuthSignInServiceSocial on AuthSignInService {
  Future<bool> _isProviderLinkedCurrentUser(String providerId) async {
    var user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.reload();
      user = _auth.currentUser ?? user;
    } catch (error) {
      debugPrint('[AuthSocial] Không tải lại được provider hiện tại: $error');
    }

    final providerData = user?.providerData ?? <firebase_auth.UserInfo>[];
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

  Future<void> linkGoogleToCurrentUser() async {
    var user = _auth.currentUser;
    if (user == null) {
      throw UiCopy.text('copy_ba3ce6b45be4');
    }

    if (await isGoogleLinkedCurrentUser()) {
      return;
    }

    final provider = firebase_auth.GoogleAuthProvider()..addScope('email');
    provider.setCustomParameters({'prompt': 'select_account'});

    try {
      if (kIsWeb) {
        await user.linkWithPopup(provider);
      } else {
        final googleSignIn = _googleSignIn ??= _googleSignInBuilder();
        if (!AuthSignInService._isGoogleSignInInitialized) {
          final initCompleter = Completer<void>();
          googleSignIn
              .initialize()
              .then((_) {
                if (!initCompleter.isCompleted) initCompleter.complete();
              })
              .catchError((error) {
                if (!initCompleter.isCompleted) {
                  initCompleter.completeError(error);
                } else {
                  debugPrint('Late Google init error swallowed: $error');
                }
              });
          await initCompleter.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw UiCopy.text('copy_90ca8dbde435'),
          );
          AuthSignInService._isGoogleSignInInitialized = true;
        }

        // Sign out trước để force hiện picker, tránh cached token expired
        try {
          await googleSignIn.signOut();
        } catch (error) {
          debugPrint('[AuthSocial] Không xóa được phiên Google cũ: $error');
        }

        final authCompleter = Completer<dynamic>();
        googleSignIn
            .authenticate(scopeHint: const ['email'])
            .then((user) {
              if (!authCompleter.isCompleted) authCompleter.complete(user);
            })
            .catchError((error) {
              if (!authCompleter.isCompleted) {
                authCompleter.completeError(error);
              } else {
                debugPrint('Late Google auth error swallowed: $error');
              }
            });

        final googleUser = await authCompleter.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () =>
              throw UiCopy.text('copy_fe32cbfef9b5'),
        );
        if (googleUser == null) return;
        final googleAuth = await googleUser.authentication;
        if ((googleAuth.idToken ?? '').isEmpty) {
          throw UiCopy.text('copy_f82aa856e91f');
        }

        final credential = firebase_auth.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await user.linkWithCredential(credential);
      }

      await user.reload();
      user = _auth.currentUser ?? user;
      await _houseContextService.syncSecurityEmailForCurrentUser(user: user);
    } on firebase_auth.FirebaseAuthException catch (error) {
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
      final raw = error.toString();
      if (raw.contains('10') ||
          raw.contains('sign_in_failed') ||
          raw.contains('ApiException')) {
        throw UiCopy.text('copy_d3bda4768414');
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            L10nService().translate('auth_fallback_google_link'),
      ).message;
    }
  }

  Future<void> linkAppleToCurrentUser() async {
    var user = _auth.currentUser;
    if (user == null) {
      throw UiCopy.text('copy_cb88670faeb1');
    }

    if (await isAppleLinkedCurrentUser()) {
      return;
    }

    try {
      if (kIsWeb) {
        final provider = firebase_auth.AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        await user.linkWithPopup(provider);
      } else {
        final isAvailable = await SignInWithApple.isAvailable();
        if (!isAvailable) {
          throw UiCopy.text('copy_422db9a6de1d');
        }

        final rawNonce = generateNonce();
        final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
          state: generateNonce(length: 12),
          webAuthenticationOptions: _usesNativeAppleFlow
              ? null
              : _buildAppleWebAuthenticationOptions(),
        );

        final oauthCredential = _buildAppleFirebaseCredential(
          appleCredential,
          rawNonce,
        );
        await user.linkWithCredential(oauthCredential);
      }

      await user.reload();
      user = _auth.currentUser ?? user;
      await _houseContextService.syncSecurityEmailForCurrentUser(user: user);
    } on firebase_auth.FirebaseAuthException catch (error) {
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
        fallbackMessage:
            L10nService().translate('auth_fallback_apple_link'),
      ).message;
    }
  }

  Future<void> createPasswordForCurrentUser(String newPassword) async {
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
    if (await isPasswordLinkedCurrentUser()) {
      throw UiCopy.text('copy_5a8d7b0b0484');
    }

    Future<void> linkPasswordCredential() async {
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: normalizedPassword,
      );
      await user!.linkWithCredential(credential);
    }

    try {
      await linkPasswordCredential();
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        await _reauthenticateCurrentUserWithLinkedProvider(user);
        user = _auth.currentUser ?? user;
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
        fallbackMessage:
            L10nService().translate('auth_fallback_password_create'),
      ).message;
    }

    await user.reload();
    user = _auth.currentUser ?? user;
    try {
      await _houseContextService.syncSecurityEmailForCurrentUser(user: user);
    } catch (error) {
      debugPrint('[AuthSocial] Không đồng bộ được email bảo mật: $error');
    }
  }

  Future<void> _reauthenticateCurrentUserWithLinkedProvider(
    firebase_auth.User user,
  ) async {
    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .toSet();
    if (providerIds.contains('google.com')) {
      await _reauthenticateCurrentUserWithGoogle(user);
      return;
    }
    if (providerIds.contains('facebook.com')) {
      throw UiCopy.text('copy_759b8bdbf042');
    }
    throw UiCopy.text('copy_647e89e2e05d');
  }

  Future<void> _reauthenticateCurrentUserWithGoogle(
    firebase_auth.User user,
  ) async {
    try {
      if (kIsWeb) {
        final provider = firebase_auth.GoogleAuthProvider()..addScope('email');
        provider.setCustomParameters({'prompt': 'select_account'});
        await user.reauthenticateWithPopup(provider);
        return;
      }

      final googleSignIn = _googleSignIn ??= _googleSignInBuilder();
      if (!AuthSignInService._isGoogleSignInInitialized) {
        final initCompleter = Completer<void>();
        googleSignIn
            .initialize()
            .then((_) {
              if (!initCompleter.isCompleted) initCompleter.complete();
            })
            .catchError((error) {
              if (!initCompleter.isCompleted) {
                initCompleter.completeError(error);
              } else {
                debugPrint('Late Google init error swallowed: $error');
              }
            });
        await initCompleter.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw UiCopy.text('copy_90ca8dbde435'),
        );
        AuthSignInService._isGoogleSignInInitialized = true;
      }

      // Sign out trước để force hiện picker, tránh cached token expired
      try {
        await googleSignIn.signOut();
      } catch (error) {
        debugPrint('[AuthSocial] Không xóa được phiên Google cũ: $error');
      }

      final authCompleter = Completer<dynamic>();
      googleSignIn
          .authenticate(scopeHint: const ['email'])
          .then((user) {
            if (!authCompleter.isCompleted) authCompleter.complete(user);
          })
          .catchError((error) {
            if (!authCompleter.isCompleted) {
              authCompleter.completeError(error);
            } else {
              debugPrint('Late Google auth error swallowed: $error');
            }
          });

      final googleUser = await authCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
            throw UiCopy.text('copy_fe32cbfef9b5'),
      );
      if (googleUser == null) {
        throw UiCopy.text('copy_4cccee9577ae');
      }
      final googleAuth = await googleUser.authentication;
      if ((googleAuth.idToken ?? '').isEmpty) {
        throw UiCopy.text('copy_8802343cdb61');
      }

      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
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
        fallbackMessage:
            L10nService().translate('auth_fallback_google_reauthenticate'),
      ).message;
    }
  }
}
