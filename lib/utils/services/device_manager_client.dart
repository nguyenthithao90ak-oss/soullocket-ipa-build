import 'dart:async';

class DeviceManagerListing {
  final String houseId;
  final List<Map<String, dynamic>> devices;
  final Map<String, dynamic> management;
  final int policyVersion;

  const DeviceManagerListing({
    required this.houseId,
    required this.devices,
    this.management = const {},
    this.policyVersion = 0,
  });

  factory DeviceManagerListing.fromServer(dynamic data) {
    if (data is! Map ||
        data['devices'] is! List ||
        data['houseId'] is! String ||
        (data['houseId'] as String).trim().isEmpty) {
      throw const FormatException('Invalid device list response');
    }
    final policyVersion = data['policyVersion'] == 2 ? 2 : 0;
    final rawManagement = data['management'];
    final management = policyVersion == 2 && rawManagement is Map
        ? Map<String, dynamic>.from(rawManagement)
        : <String, dynamic>{'role': 'unverified', 'canManage': false};
    final canManage =
        management['canManage'] == true &&
        (management['role'] == 'creator' ||
            management['role'] == 'established');
    final devices = (data['devices'] as List)
        .whereType<Map>()
        .map((raw) {
          final device = Map<String, dynamic>.from(raw)
            ..remove('deviceProof')
            ..remove('installation_proof_hash');
          device['can_manage'] =
              policyVersion == 2 &&
              canManage &&
              device['can_manage'] == true &&
              device['protected'] != true;
          return device;
        })
        .toList(growable: false);
    return DeviceManagerListing(
      houseId: data['houseId'],
      devices: devices,
      management: {...management, 'canManage': canManage},
      policyVersion: policyVersion,
    );
  }
}

abstract class DeviceManagerClient {
  String? get sessionUid;
  Stream<String?> get sessionChanges;
  Future<String> getCurrentDeviceIdentifier();
  Future<Map<String, String>> getCurrentDeviceSnapshot();
  Future<bool> isSecurityDeviceSignalsAllowed();
  Future<void> registerCurrentDevice({bool throwOnError = false});
  Future<DeviceManagerListing> loadDeviceListing();
  Future<void> approveDevice(String deviceId, {String? expectedHouseId});
  Future<void> blockDevice(String deviceId, {String? expectedHouseId});
  Future<void> deleteDevice(String deviceId, {String? expectedHouseId});
}
