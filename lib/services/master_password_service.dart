import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MasterPasswordService {
  static final MasterPasswordService _instance =
      MasterPasswordService._internal();
  factory MasterPasswordService() => _instance;
  MasterPasswordService._internal();

  static const String _hostDeviceKey = 'isHostDevice';
  static const String _masterPasswordHashKey = 'masterPasswordHash';

  // SHA-256 hash of the default master password — never stored as plain text
  static const String _defaultMasterHash =
      'c9d9d7b76365c6f635de6020e6e4c9eab551205ef025c33c64f677fee0a69a50';

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Returns true if this device is registered as a Host Device
  bool isHostDevice() {
    final box = Hive.box<String>('settings');
    return box.get(_hostDeviceKey) == 'true';
  }

  /// Returns true if a custom master password has been set on this device
  bool isMasterPasswordSet() {
    final box = Hive.box<String>('settings');
    return box.get(_masterPasswordHashKey) != null;
  }

  /// Verifies a given password against stored hash (falls back to default hash)
  bool verifyMasterPassword(String password) {
    final box = Hive.box<String>('settings');
    final storedHash = box.get(_masterPasswordHashKey) ?? _defaultMasterHash;
    return _sha256(password) == storedHash;
  }

  /// Sets a new master password — stores only the SHA-256 hash
  Future<void> setMasterPassword(String password) async {
    final box = Hive.box<String>('settings');
    await box.put(_masterPasswordHashKey, _sha256(password));
  }

  /// Permanently marks this device as the Host Device
  Future<void> activateHostDevice() async {
    final box = Hive.box<String>('settings');
    await box.put(_hostDeviceKey, 'true');
  }

  /// Deactivates host device status (for safety)
  Future<void> deactivateHostDevice() async {
    final box = Hive.box<String>('settings');
    await box.delete(_hostDeviceKey);
  }
}
