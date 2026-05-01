const Duration kRapidActionWarningThreshold = Duration(seconds: 3);

bool shouldShowRapidActionWarning(Duration remainingCooldown) {
  return remainingCooldown > kRapidActionWarningThreshold;
}

bool shouldShowRapidActionWarningSeconds(int remainingSeconds) {
  return remainingSeconds > kRapidActionWarningThreshold.inSeconds;
}

class SilentRapidActionBlockException implements Exception {
  const SilentRapidActionBlockException();
}

bool isSilentRapidActionBlock(Object error) {
  return error is SilentRapidActionBlockException;
}
