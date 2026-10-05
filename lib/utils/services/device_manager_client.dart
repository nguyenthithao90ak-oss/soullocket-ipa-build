import 'dart:async';

class DeviceManagerListing {
  final String houseId;
  final List<Map<String, dynamic>> devices;

  const DeviceManagerListing({required this.houseId, required this.devices});
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
