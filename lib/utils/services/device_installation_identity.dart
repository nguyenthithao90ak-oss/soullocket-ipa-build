import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'secure_storage_service.dart';

class DeviceInstallationIdentity {
  const DeviceInstallationIdentity({
    required this.deviceId,
    required this.proof,
  });

  final String deviceId;
  final String proof;

  static Future<DeviceInstallationIdentity> forUid(String uid) async {
    if (uid.trim().isEmpty) throw StateError('Missing authenticated identity');
    final proof = await SecureStorageService.instance.installationCredential();
    final identifier = sha256.convert(utf8.encode('$uid:$proof')).toString();
    return DeviceInstallationIdentity(
      deviceId: 'device_$identifier',
      proof: proof,
    );
  }

  Map<String, String> get payload => {
    'deviceId': deviceId,
    'deviceProof': proof,
  };
}
