part of 'auth_sign_in_service.dart';

extension AuthSignInServiceSocial on AuthSignInService {
  Future<bool> _isProviderLinkedCurrentUser(String providerId) async {
    var user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.reload();
      user = _auth.currentUser ?? user;
    } catch (_) {}

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
      throw 'Bạn cần đăng nhập trước khi liên kết Google.';
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
          googleSignIn.initialize().then((_) {
            if (!initCompleter.isCompleted) initCompleter.complete();
          }).catchError((error) {
            if (!initCompleter.isCompleted) {
              initCompleter.completeError(error);
            } else {
              debugPrint('Late Google init error swallowed: $error');
            }
          });
          await initCompleter.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw 'Thời gian chờ Google quá lâu. Vui lòng thử lại.',
          );
          AuthSignInService._isGoogleSignInInitialized = true;
        }

        // Sign out trước để force hiện picker, tránh cached token expired
        try {
          await googleSignIn.signOut();
        } catch (_) {}

        final authCompleter = Completer<dynamic>();
        googleSignIn.authenticate(
          scopeHint: const ['email'],
        ).then((user) {
          if (!authCompleter.isCompleted) authCompleter.complete(user);
        }).catchError((error) {
          if (!authCompleter.isCompleted) {
            authCompleter.completeError(error);
          } else {
            debugPrint('Late Google auth error swallowed: $error');
          }
        });

        final googleUser = await authCompleter.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () =>
              throw 'Bạn đã để màn hình đăng nhập Google quá lâu hoặc chưa hoàn tất thao tác. Vui lòng thử lại.',
        );
        if (googleUser == null) return;
        final googleAuth = await googleUser.authentication;
        if ((googleAuth.idToken ?? '').isEmpty) {
          throw 'Google không trả về ID token hợp lệ. Vui lòng thử lại.';
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
          throw 'Email Google này đã liên kết với tài khoản khác.';
        case 'requires-recent-login':
          throw 'Phiên đăng nhập đã cũ. Hãy đăng xuất rồi đăng nhập lại trước khi liên kết Google.';
        case 'popup-closed-by-user':
          throw 'Bạn đã đóng cửa sổ đăng nhập Google.';
        case 'popup-blocked':
        case 'cancelled-popup-request':
          throw 'Popup Google đang bị chặn. Hãy cho phép popup rồi thử lại.';
        case 'network-request-failed':
          throw 'Lỗi kết nối hoặc sự cố từ Google, chưa thể liên kết Google lúc này.';
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
        throw 'Bạn đã huỷ đăng nhập Google.';
      }
      final raw = error.toString();
      if (raw.contains('10') ||
          raw.contains('sign_in_failed') ||
          raw.contains('ApiException')) {
        throw 'Đăng nhập Google gặp sự cố ở bước xác thực tài khoản. Vui lòng thử lại sau.';
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không liên kết Google được: hãy kiểm tra tài khoản Google, trạng thái đăng nhập và kết nối mạng.',
      ).message;
    }
  }

  Future<void> linkAppleToCurrentUser() async {
    var user = _auth.currentUser;
    if (user == null) {
      throw 'Bạn cần đăng nhập trước khi liên kết Apple.';
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
          throw 'Thiết bị hoặc bản build này chưa hỗ trợ Sign in with Apple.';
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

        final oauthCredential =
            _buildAppleFirebaseCredential(appleCredential, rawNonce);
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
          throw 'Email Apple này đã liên kết với tài khoản khác.';
        case 'requires-recent-login':
          throw 'Phiên đăng nhập đã cũ. Hãy đăng xuất rồi đăng nhập lại trước khi liên kết Apple.';
        case 'popup-closed-by-user':
          return;
        case 'popup-blocked':
          throw 'Popup liên kết Apple đang bị chặn. Hãy cho phép popup rồi thử lại.';
        case 'operation-not-allowed':
          throw kDebugMode
              ? 'Firebase Authentication chưa bật nhà cung cấp Apple.'
              : 'Liên kết Apple chưa sẵn sàng trên bản app này.';
        case 'network-request-failed':
          throw 'Lỗi kết nối, chưa thể liên kết Apple lúc này.';
        default:
          throw handleFirebaseAuthError(error);
      }
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return;
      }
      throw kDebugMode
          ? 'Apple trả về lỗi xác thực (${error.code}). Hãy kiểm tra cấu hình Apple Sign In.'
          : 'Liên kết Apple chưa hoàn tất được. Hãy thử lại sau.';
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không liên kết Apple được: hãy kiểm tra Apple ID, quyền đăng nhập và kết nối mạng.',
      ).message;
    }
  }

  Future<void> createPasswordForCurrentUser(String newPassword) async {
    var user = _auth.currentUser;
    if (user == null) {
      throw 'Bạn cần đăng nhập trước khi tạo mật khẩu.';
    }

    final email = user.email?.trim() ?? '';
    final normalizedPassword = newPassword.trim();
    if (email.isEmpty) {
      throw 'Tài khoản hiện tại chưa có email nên chưa thể tạo mật khẩu đăng nhập.';
    }
    if (normalizedPassword.length < 6) {
      throw 'Mật khẩu phải có ít nhất 6 ký tự.';
    }
    if (await isPasswordLinkedCurrentUser()) {
      throw 'Tài khoản này đã có mật khẩu đăng nhập. Hãy dùng phần đổi mật khẩu.';
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
        throw 'Email này đã gắn với một tài khoản khác nên chưa thể tạo mật khẩu ở đây.';
      } else {
        throw handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không tạo được mật khẩu đăng nhập: hãy kiểm tra mật khẩu mới, trạng thái đăng nhập và kết nối mạng.',
      ).message;
    }

    await user.reload();
    user = _auth.currentUser ?? user;
    try {
      await _houseContextService.syncSecurityEmailForCurrentUser(user: user);
    } catch (_) {}
  }

  Future<void> _reauthenticateCurrentUserWithLinkedProvider(
    firebase_auth.User user,
  ) async {
    final providerIds =
        user.providerData.map((provider) => provider.providerId).toSet();
    if (providerIds.contains('google.com')) {
      await _reauthenticateCurrentUserWithGoogle(user);
      return;
    }
    if (providerIds.contains('facebook.com')) {
      await _reauthenticateCurrentUserWithFacebook(user);
      return;
    }
    throw 'Phiên đăng nhập đã cũ. Hãy đăng xuất rồi đăng nhập lại bằng Google hoặc Facebook trước khi tạo mật khẩu.';
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
        googleSignIn.initialize().then((_) {
          if (!initCompleter.isCompleted) initCompleter.complete();
        }).catchError((error) {
          if (!initCompleter.isCompleted) {
            initCompleter.completeError(error);
          } else {
            debugPrint('Late Google init error swallowed: $error');
          }
        });
        await initCompleter.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw 'Thời gian chờ Google quá lâu. Vui lòng thử lại.',
        );
        AuthSignInService._isGoogleSignInInitialized = true;
      }

      // Sign out trước để force hiện picker, tránh cached token expired
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final authCompleter = Completer<dynamic>();
      googleSignIn.authenticate(
        scopeHint: const ['email'],
      ).then((user) {
        if (!authCompleter.isCompleted) authCompleter.complete(user);
      }).catchError((error) {
        if (!authCompleter.isCompleted) {
          authCompleter.completeError(error);
        } else {
          debugPrint('Late Google auth error swallowed: $error');
        }
      });

      final googleUser = await authCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
            throw 'Bạn đã để màn hình đăng nhập Google quá lâu hoặc chưa hoàn tất thao tác. Vui lòng thử lại.',
      );
      if (googleUser == null) {
        throw 'Bạn đã huỷ đăng nhập Google.';
      }
      final googleAuth = await googleUser.authentication;
      if ((googleAuth.idToken ?? '').isEmpty) {
        throw 'Google không trả về ID token hợp lệ để xác minh lại tài khoản.';
      }

      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'user-mismatch':
          throw 'Bạn cần chọn đúng tài khoản Google đã dùng để đăng nhập trước đó.';
        case 'popup-closed-by-user':
          throw 'Bạn đã đóng cửa sổ xác minh lại Google.';
        case 'popup-blocked':
        case 'cancelled-popup-request':
          throw 'Popup Google đang bị chặn. Hãy cho phép popup rồi thử lại.';
        case 'network-request-failed':
          throw 'Lỗi kết nối hoặc sự cố từ Google, chưa thể xác minh lại Google lúc này.';
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
        throw 'Bạn đã huỷ đăng nhập Google.';
      }
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không xác minh lại Google được: hãy chọn đúng tài khoản Google đang liên kết và kiểm tra cấu hình chữ ký SHA-1.',
      ).message;
    }
  }

  Future<void> _reauthenticateCurrentUserWithFacebook(
    firebase_auth.User user,
  ) async {
    try {
      if (kIsWeb) {
        final provider = firebase_auth.FacebookAuthProvider();
        provider.addScope('email');
        provider.addScope('public_profile');
        provider.setCustomParameters({'display': 'popup'});
        await user.reauthenticateWithPopup(provider);
        return;
      }

      try {
        await _facebookAuth.logOut();
      } catch (_) {}

      final loginBehavior = defaultTargetPlatform == TargetPlatform.android
          ? LoginBehavior.dialogOnly
          : LoginBehavior.nativeWithFallback;
      final loginResult = await _facebookAuth.login(
        permissions: const ['email', 'public_profile'],
        loginBehavior: loginBehavior,
        loginTracking: LoginTracking.enabled,
      );

      switch (loginResult.status) {
        case LoginStatus.success:
          final accessToken = loginResult.accessToken;
          if (accessToken == null) {
            throw 'Facebook không trả về access token hợp lệ.';
          }
          final credential = accessToken is LimitedToken
              ? firebase_auth.OAuthProvider('facebook.com').credential(
                  idToken: accessToken.tokenString,
                  rawNonce: accessToken.nonce,
                )
              : firebase_auth.FacebookAuthProvider.credential(
                  accessToken.tokenString.trim(),
                );
          await user.reauthenticateWithCredential(credential);
          return;
        case LoginStatus.cancelled:
          throw 'Bạn đã hủy xác minh lại Facebook.';
        case LoginStatus.operationInProgress:
          throw 'Facebook đang xử lý đăng nhập. Vui lòng đợi một chút rồi thử lại.';
        case LoginStatus.failed:
          throw normalizeFacebookLoginFailureMessage(loginResult.message);
      }
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'user-mismatch') {
        throw 'Bạn cần chọn đúng tài khoản Facebook đã dùng để đăng nhập trước đó.';
      }
      if (error.code == 'network-request-failed') {
        throw 'Lỗi kết nối, chưa thể xác minh lại Facebook lúc này.';
      }
      throw handleFirebaseAuthError(error);
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không xác minh lại Facebook được: hãy chọn đúng tài khoản Facebook đang liên kết và kiểm tra mạng.',
      ).message;
    }
  }
}
