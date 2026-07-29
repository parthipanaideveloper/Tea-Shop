import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SecurityStatus {
  final bool isRooted;
  final bool isEmulator;
  final bool isDebuggerConnected;
  final bool isSignatureValid;
  final bool isPackageNameValid;
  final bool isSideloaded;
  final String actualSignature;

  SecurityStatus({
    required this.isRooted,
    required this.isEmulator,
    required this.isDebuggerConnected,
    required this.isSignatureValid,
    required this.isPackageNameValid,
    required this.isSideloaded,
    this.actualSignature = '',
  });

  bool get hasThreat =>
      isRooted ||
      isEmulator ||
      isDebuggerConnected ||
      !isSignatureValid ||
      !isPackageNameValid;

  String get threatMessage {
    if (isRooted)
      return 'Security Violation: Device is rooted. Execution blocked.';
    if (isEmulator)
      return 'Security Violation: Running on an emulator. Execution blocked.';
    if (isDebuggerConnected)
      return 'Security Violation: Active debugger detected.';
    if (!isSignatureValid) {
      return 'Security Violation: Unauthorized APK modification / Re-signing detected.\n\nActual Signature:\n$actualSignature\n\nTo lock this app, copy this key to expectedReleaseSignature in security_service.dart and rebuild.';
    }
    if (!isPackageNameValid)
      return 'Security Violation: App cloning or repackaging detected.';
    return '';
  }
}

class SecurityService {
  static const _channel = MethodChannel('com.dts.pos/security');

  // Hardcoded official production release signature hash
  // (In production, replace with your actual release SHA-256 fingerprint, lowercase without colons)
  static const String _expectedReleaseSignature =
      'YOUR_RELEASE_KEY_SHA256_FINGERPRINT_HERE';

  static const String _licensingSalt = 'DtsSecureLicensingSalt2026';

  String generateActivationKey(String deviceId, String nonce) {
    final cleanDevice = deviceId.trim().toUpperCase();
    final combined = '$cleanDevice$_licensingSalt$nonce';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    final hex = digest.toString().toUpperCase();

    // Take first 12 characters and partition into 3 blocks
    final part1 = hex.substring(0, 4);
    final part2 = hex.substring(4, 8);
    final part3 = hex.substring(8, 12);

    // Key format: NONCE-PART1-PART2-PART3
    return '$nonce-$part1-$part2-$part3';
  }

  bool verifyActivationKey(String deviceId, String enteredKey) {
    final cleanKey = enteredKey.trim().toUpperCase();
    final parts = cleanKey.split('-');
    if (parts.length != 4) return false;

    final nonce = parts[0];
    final expected = generateActivationKey(deviceId, nonce);
    return cleanKey == expected;
  }

  Future<String> getDeviceId() async {
    if (Platform.isWindows) {
      try {
        final res = Process.runSync('wmic', ['csproduct', 'get', 'uuid']);
        final stdout = res.stdout.toString();
        final lines = stdout.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty && l != 'UUID').toList();
        if (lines.isNotEmpty && lines.first.length > 5) {
          return 'WIN-${lines.first}';
        }
      } catch (_) {}
      return 'WIN-${Platform.localHostname}';
    }
    try {
      final String? deviceId = await _channel.invokeMethod<String>(
        'getDeviceId');
      return deviceId ?? 'unknown_device_id';
    } catch (e) {
      return 'unknown_device_id';
    }
  }

  Future<String> getApkSignature() async {
    if (Platform.isWindows) return '';
    try {
      final String? signature = await _channel.invokeMethod<String>(
        'getApkSignature');
      return signature ?? '';
    } catch (e) {
      return '';
    }
  }

  Future<String> getInstallerSource() async {
    if (Platform.isWindows) return 'windows';
    try {
      final String? source = await _channel.invokeMethod<String>(
        'getInstallerSource');
      return source ?? 'sideload';
    } catch (e) {
      return 'sideload';
    }
  }

  Future<bool> checkRoot() async {
    if (Platform.isWindows) return false;
    try {
      final bool? rooted = await _channel.invokeMethod<bool>('checkRoot');
      return rooted ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkEmulator() async {
    if (Platform.isWindows) return false;
    try {
      final bool? emulator = await _channel.invokeMethod<bool>('checkEmulator');
      return emulator ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkDebugger() async {
    if (Platform.isWindows) return false;
    try {
      final bool? debugger = await _channel.invokeMethod<bool>('checkDebugger');
      return debugger ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<SecurityStatus> checkAppIntegrity() async {
    // If in debug/profile mode (dev environments) or on Windows, bypass integrity block checks
    if (kDebugMode || kProfileMode || Platform.isWindows) {
      return SecurityStatus(
        isRooted: false,
        isEmulator: false,
        isDebuggerConnected: false,
        isSignatureValid: true,
        isPackageNameValid: true,
        isSideloaded: false,
        actualSignature: '');
    }

    final rooted = await checkRoot();
    final emulator = await checkEmulator();
    final debugger = await checkDebugger();
    final signature = await getApkSignature();
    final installer = await getInstallerSource();

    final isSigValid =
        _expectedReleaseSignature ==
            'YOUR_RELEASE_KEY_SHA256_FINGERPRINT_HERE' ||
        signature.trim().toLowerCase() ==
            _expectedReleaseSignature.toLowerCase();

    // In production, package name must match perfectly
    const isPackValid =
        true; // Placeholder for package check against _expectedPackageName

    return SecurityStatus(
      isRooted: rooted,
      isEmulator: emulator,
      isDebuggerConnected: debugger,
      isSignatureValid: isSigValid,
      isPackageNameValid: isPackValid,
      isSideloaded: installer == 'sideload',
      actualSignature: signature);
  }
}
