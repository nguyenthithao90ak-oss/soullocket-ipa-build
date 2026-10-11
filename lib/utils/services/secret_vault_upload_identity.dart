import 'dart:math';

abstract final class SecretVaultUploadIdentity {
  static String scopeKey(String uid, String houseId) =>
      'secret_vault_v2_${uid}_$houseId';

  static Map<String, String> requestIds(
    Iterable<String> paths,
    Map<String, dynamic> current,
  ) {
    final random = Random.secure();
    return {
      for (final path in paths)
        path: RegExp(r'^[a-f0-9]{32}$').hasMatch(current[path]?.toString() ?? '')
            ? current[path].toString()
            : List.generate(16, (_) => random.nextInt(256).toRadixString(16)
                .padLeft(2, '0')).join(),
    };
  }
}
