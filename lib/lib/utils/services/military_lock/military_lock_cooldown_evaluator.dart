part of '../military_lock_service.dart';

extension _MilitaryLockCooldownEvaluator on MilitaryLockService {
  Future<PinUnlockResult> _attemptUnlock({
    required LockSecretRecord expectedSecret,
    required String attempt,
    String? houseId,
  }) async {
    final state = await _getUnlockGuardState(houseId: houseId);
    if (state.isLocked) {
      return PinUnlockResult(
        status: PinUnlockStatus.blocked,
        message: _blockedUnlockMessage(state.remainingLockSeconds),
        remainingLockSeconds: state.remainingLockSeconds,
        failedAttempts: state.failedAttempts,
        canRecoverWithEmail:
            state.failedAttempts >= MilitaryLockService._unlockMaxAttempts,
      );
    }

    if (_secretsMatch(expectedSecret, attempt)) {
      await _clearUnlockGuard(houseId: houseId);
      if (_shouldUpgradeStoredSecret(expectedSecret)) {
        await _upgradeStoredLockSecret(
          previousSecret: expectedSecret,
          plainPin: attempt,
          houseId: houseId,
        );
      }
      return const PinUnlockResult(status: PinUnlockStatus.success);
    }

    final updatedState = await _recordUnlockFailure(houseId: houseId);
    if (updatedState.isLocked) {
      return PinUnlockResult(
        status: PinUnlockStatus.blocked,
        message: _blockedUnlockMessage(updatedState.remainingLockSeconds),
        remainingLockSeconds: updatedState.remainingLockSeconds,
        failedAttempts: updatedState.failedAttempts,
        canRecoverWithEmail: updatedState.failedAttempts >=
            MilitaryLockService._unlockMaxAttempts,
      );
    }

    return PinUnlockResult(
      status: PinUnlockStatus.invalid,
      message: _invalidUnlockMessage(updatedState.failedAttempts),
      remainingAttempts:
          _remainingAttemptsBeforeLock(updatedState.failedAttempts),
      failedAttempts: updatedState.failedAttempts,
      canRecoverWithEmail:
          updatedState.failedAttempts >= MilitaryLockService._unlockMaxAttempts,
    );
  }

  Future<_UnlockGuardState> _getUnlockGuardState({String? houseId}) async {
    final namespace = await _unlockGuardNamespace(houseId: houseId);
    final failedAttemptsStr =
        await _secureStorage.read(key: _unlockFailedAttemptsKey(namespace));
    final lockUntilStr =
        await _secureStorage.read(key: _unlockLockUntilKey(namespace));

    final failedAttempts = int.tryParse(failedAttemptsStr ?? '0') ?? 0;
    final storedLockUntil = int.tryParse(lockUntilStr ?? '0') ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final lockUntil = storedLockUntil > now ? storedLockUntil : 0;
    if (storedLockUntil != 0 && lockUntil == 0) {
      await _secureStorage.delete(key: _unlockLockUntilKey(namespace));
    }
    return _UnlockGuardState(
      failedAttempts: failedAttempts,
      lockUntilEpochMs: lockUntil,
    );
  }

  Future<_UnlockGuardState> _recordUnlockFailure({String? houseId}) async {
    final namespace = await _unlockGuardNamespace(houseId: houseId);
    final failedKey = _unlockFailedAttemptsKey(namespace);
    final lockKey = _unlockLockUntilKey(namespace);

    final failedStr = await _secureStorage.read(key: failedKey);
    final nextFailedAttempts = (int.tryParse(failedStr ?? '0') ?? 0) + 1;
    await _secureStorage.write(
      key: failedKey,
      value: nextFailedAttempts.toString(),
    );

    final lockStr = await _secureStorage.read(key: lockKey);
    var lockUntil = int.tryParse(lockStr ?? '0') ?? 0;

    if (nextFailedAttempts % MilitaryLockService._unlockMaxAttempts == 0) {
      final durationSeconds =
          _lockDurationSecondsForAttempts(nextFailedAttempts);
      lockUntil =
          DateTime.now().millisecondsSinceEpoch + (durationSeconds * 1000);
      await _secureStorage.write(key: lockKey, value: lockUntil.toString());
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lockUntil <= now) {
        lockUntil = 0;
        await _secureStorage.delete(key: lockKey);
      }
    }

    return _UnlockGuardState(
      failedAttempts: nextFailedAttempts,
      lockUntilEpochMs: lockUntil,
    );
  }

  Future<void> _clearUnlockGuard({String? houseId}) async {
    final namespace = await _unlockGuardNamespace(houseId: houseId);
    await _secureStorage.delete(key: _unlockFailedAttemptsKey(namespace));
    await _secureStorage.delete(key: _unlockLockUntilKey(namespace));
  }

  Future<String> _unlockGuardNamespace({String? houseId}) async {
    final resolvedHouseId = await resolveHouseId(houseId: houseId);
    if (resolvedHouseId != null && resolvedHouseId.isNotEmpty) {
      return 'house_$resolvedHouseId';
    }

    final userUid = _auth.currentUser?.uid.trim() ?? '';
    if (userUid.isNotEmpty) {
      return 'user_$userUid';
    }

    return 'local';
  }

  String _unlockFailedAttemptsKey(String namespace) {
    return '${MilitaryLockService._prefUnlockFailedAttemptsPrefix}$namespace';
  }

  String _unlockLockUntilKey(String namespace) {
    return '${MilitaryLockService._prefUnlockLockUntilPrefix}$namespace';
  }

  int _remainingAttemptsBeforeLock(int failedAttempts) {
    final remainder = failedAttempts % MilitaryLockService._unlockMaxAttempts;
    return remainder == 0
        ? MilitaryLockService._unlockMaxAttempts
        : MilitaryLockService._unlockMaxAttempts - remainder;
  }

  int _lockDurationSecondsForAttempts(int failedAttempts) {
    if (failedAttempts >= 10) return 300;
    if (failedAttempts >= 5) return 30;
    return 0;
  }

  String _invalidUnlockMessage(int failedAttempts) {
    final remainingAttempts = _remainingAttemptsBeforeLock(failedAttempts);
    if (remainingAttempts == 1) {
      return 'Mã khóa chưa đúng. Còn 1 lần thử trước khi tạm khóa.';
    }
    return 'Mã khóa chưa đúng. Còn $remainingAttempts lần thử trước khi tạm khóa.';
  }

  String _blockedUnlockMessage(int remainingSeconds) {
    return 'Bạn đã nhập sai quá nhiều lần. Thử lại sau $remainingSeconds giây.';
  }
}
